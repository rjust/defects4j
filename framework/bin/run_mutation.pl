#!/usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2015 René Just, Darioush Jalali, and Defects4J contributors.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

=pod

=head1 NAME

run_mutation.pl -- Run mutation analysis for generated test suites.

=head1 SYNOPSIS

run_mutation.pl -p project_id -d suite_dir -o out_dir [-f include_file_pattern] [-v version_id] [-t tmp_dir] [-D]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>> 

The id of the project for which the mutation analysis is performed.

=item B<-d F<suite_dir>> 

The directory that contains the test suite archives.

=item B<-o F<out_dir>> 

The output directory for the mutation results and log files. 

=item B<-f C<include__file_pattern>> 

The pattern of the test class file names that should be included in the mutation analysis (optional). 
Per default all files (*.java) are included. 

=item B<-v C<version_id>> 

Only perform mutation analysis for this version id (optional). Per default all
suitable version ids are considered. 

=item B<-t F<tmp_dir>> 

The temporary root directory to be used to check out revisions (optional).
The default is F</tmp>.

=item B<-D> 

Debug: Enable verbose logging and do not delete the temporary check-out directory
(optional).

=back

=head1 DESCRIPTION

Performs mutation analysis for each provided test suite (i.e., each test suite 
archive in F<suite_dir>) on the program version for which it was generated. 
B<Each test suite has to pass on the program version for which it was generated.>

The results of the mutation analysis are stored in the database table 
F<"out_dir"/$TAB_MUTATION>. The corresponding log files are stored in 
F<"out_dir"/"${TAB_MUTATION}_log">.

=cut
use warnings;
use strict;


use FindBin;
use File::Basename;                                                              
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Mutation;
use Project;
use Utils;
use Log;
use DB;

#
# Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('p:d:v:t:o:f:D', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{d} and defined $cmd_opts{o};

# Ensure that directory of test suites exists
-d $cmd_opts{d} or die "Test suite directory $cmd_opts{d} does not exist!";

my $PID = $cmd_opts{p};
my $SUITE_DIR = abs_path($cmd_opts{d});
my $VID = $cmd_opts{v} if defined $cmd_opts{v};
my $INCL = $cmd_opts{f} // "*.java";
# Enable debugging if flag is set
$DEBUG = 1 if defined $cmd_opts{D};

# Set up project
my $project = Project::create_project($PID);

# Check format of target version id
if (defined $VID) {
    my @ids = $project->get_version_ids();
    $VID =~ /^(\d+)[bf]$/ or die "Wrong version_id format: $VID! Expected: \\d+[bf]";
    # Verify that the bug_id is valid if a version_id is provided (version_id = bug_id + [bf])
    $1 ~~ @ids or die "Version id ($VID) does not exist in project: $PID";
} 

# Output directory for results
system("mkdir -p $cmd_opts{o}");
my $OUT_DIR = abs_path($cmd_opts{o});

# Temporary directory for execution
my $TMP_DIR = Utils::get_tmp_dir($cmd_opts{t}); 
system("mkdir -p $TMP_DIR");

=pod

=head2 Logging

By default, the script logs all errors and warnings to run_mutation.pl.log in
the temporary project root.

Upon success, the log file of this script and the detailed mutation results for 
each executed test suite are copied to:
F<"out_dir"/${TAB_MUTATION}_log/"project_id">.

=cut
# Log directory and file
my $LOG_DIR = "$OUT_DIR/${TAB_MUTATION}_log/$PID"; 
my $LOG_FILE = "$LOG_DIR/" . basename($0) . ".log";
system("mkdir -p $LOG_DIR");

# Open temporary log file
my $LOG = Log::create_log("$TMP_DIR/". basename($0) . ".log");
$LOG->log_time("Start mutation analysis");

=pod

=head2 Test Suites

All test suites in C<suite_dir> have to be provided as an archive that conforms
to the following naming convention: 

B<C<project_id>-C<version_id>-C<test_suite_src>[.C<test_id>].tar.bz2>

Note that the C<test_id> is optional -- the default is 1.

Examples:

=over 4

=item Lang-11f-randoop.1.tar.bz2 (equal to Lang-1-randoop.tar.bz2)

=item Lang-11b-randoop.2.tar.bz2

=item Lang-12b-evosuite-weakmutation.1.tar.bz2

=item Lang-12f-evosuite-branch.1.tar.bz2

=back

=cut


# hash all test suites matching the given project_id, using the following mapping:
# version_id -> suite_src -> test_id -> "file_name"
my %test_suites;
my $count = 0;
opendir(DIR, $SUITE_DIR) or die "Cannot open directory: $SUITE_DIR!";
my @entries = readdir(DIR);
closedir(DIR);
foreach (@entries) {
    next unless /^$PID-(\d+[bf])-([^\.]+)(\.(\d+))?.tar.bz2$/;
    my $vid = $1;
    my $suite_src = "$2";
    my $test_id = $4 // 1;

    # Only hash test suites for target version id, if provided
    next if defined $VID and $vid ne $VID;

    # Init hash if necessary
    $test_suites{$vid} = {} unless defined $test_suites{$vid};
    $test_suites{$vid}->{$suite_src} = {} unless defined $test_suites{$vid}->{$suite_src};
    
    # Save archive name for current test id
    $test_suites{$vid}->{$suite_src}->{$test_id}=$_;

    ++$count;
}

$LOG->log_msg(" - Found $count test suite archive(s)");

# Directory of class lists used for mutation step
my $CLASS_DIR = "$SCRIPT_DIR/projects/$PID/modified_classes";

# Get database handle for result table
my $dbh_out = DB::get_db_handle($TAB_MUTATION, $OUT_DIR);

my $sth = $dbh_out->prepare("SELECT * FROM $TAB_MUTATION WHERE $PROJECT=? AND $TEST_SUITE=? AND $ID=? AND $TEST_ID=?") 
    or die $dbh_out->errstr;

# Iterate over all version ids
foreach my $vid (keys %test_suites) {

    # Iterate over all test suite sources (test data generation tools)
    foreach my $suite_src (keys %{$test_suites{$vid}}) {
        `mkdir -p $LOG_DIR/$suite_src`;

        # Iterate over all test suites for this source
        foreach my $test_id (keys %{$test_suites{$vid}->{$suite_src}}) {
            my $archive = $test_suites{$vid}->{$suite_src}->{$test_id};
            my $test_dir = "$TMP_DIR/$suite_src";
            
            # Skip existing entries
            $sth->execute($PID, $suite_src, $vid, $test_id);
            if ($sth->rows !=0) {
                $LOG->log_msg(" - Skipping $archive since results already exist in database!");
                next;
            }
            
            $LOG->log_msg(" - Executing test suite: $archive");
            printf ("Executing test suite: $archive\n");
            
        
            # Copy generated tests into temp directory
            system("mkdir -p $test_dir && cd $test_dir && rm -rf * && cp $SUITE_DIR/$archive . && tar -xjf $archive") == 0 
                or die "Cannot extract test suite!";
           
            # 
            # Run mutation analysis
            #
            # TODO: Avoid re-compilation/mutation of classes for the same
            # version id. Only checkout and mutate every version once: use
            # a distinct directory for each version id
            #
            _run_mutation($vid, $suite_src, $test_id, $test_dir);
        }
    }
}
# Log current time
$LOG->log_time("End mutation analysis");
$LOG->close();

# Copy log file and clean up temporary directory
system("cat $LOG->{file_name} >> $LOG_FILE") == 0 or die "Cannot copy log file";
system("rm -rf $TMP_DIR") unless $DEBUG;

#
# Run mutation analysis for tests on the version they were created for.
#
sub _run_mutation {
    my ($vid, $suite_src, $test_id, $test_dir) = @_;

    # Get archive name for current test suite
    my $archive = $test_suites{$vid}->{$suite_src}->{$test_id};
   
    $vid =~ /^(\d+)([bf])$/ or die "Unexpected version id: $vid!";
    my $bid   = $1;
    my $type  = $2;


    my $root = "$TMP_DIR/${vid}";
    $project->{prog_root} = "$root";
    _checkout($project, $vid);

    # Create mutation definitions (mml file)
    my $mml_dir = "$TMP_DIR/.mml";
    system("$UTIL_DIR/create_mml.pl -p $PID -c $CLASS_DIR -o $mml_dir -v $bid");
    my $mml_file = "$mml_dir/$bid.mml.bin";
    -e $mml_file or die "Mml file does not exist: $mml_file!";

    # Mutate source code
    $ENV{MML} = $mml_file;
    my $gen_mutants = $project->mutate();
    $gen_mutants > 0 or die "No mutants generated for $vid!";
    
    # Compile generated tests
    $project->compile_ext_tests($test_dir) == 0 or die "Tests do not compile!";

    # No need to run the test suite first. Major's preprocessing verifies that
    # all tests in the test suite pass before performing the mutation analysis.   
    my $mut_log = "$TMP_DIR/.mutation.log"; `>$mut_log`;
    my $mut_map = Mutation::mutation_analysis_ext($project, $test_dir, "$INCL", $mut_log);
    if (defined $mut_map) {
        # Add results to database table
        Mutation::insert_row($OUT_DIR, $PID, $vid, $suite_src, $test_id, $gen_mutants, $mut_map);
    } else {
        # Add incomplete results to database table to indicate a broken test suite
        Mutation::insert_row($OUT_DIR, $PID, $vid, $suite_src, $test_id, "-");
        $LOG->log_file(" - Mutation analysis failed: $archive", $mut_log);
    }
    Mutation::copy_mutation_logs($project, $vid, $suite_src, $test_id, $mut_log, $LOG_DIR);
}

#
# Checkout buggy or fixed project version
# TODO: Implement in core module
#
sub _checkout {
    my ($project, $vid) = @_;
    $vid =~ /^(\d+)([bf])$/ or die "Wrong version_id format (\\d+[bf]): $vid!";
    my $bid = $1;
    # Checkout fixed project version
    $project->checkout_id("${bid}f") == 0 or die "Cannot checkout!";
    $project->fix_tests("${bid}f");
    # Apply patch to obtain buggy version if necessary
    if ($vid=~/^(\d+)b$/) {
        my $root = $project->{prog_root};
        my $patch_dir = "$SCRIPT_DIR/projects/$PID/patches";
        my $src_patch = "$patch_dir/${bid}.src.patch";
        my $rev2 = $project->lookup("${bid}f");
        my $src_path = $project->src_dir($rev2);
        $project->apply_patch($root, $src_patch, $src_path) == 0 or die;
        # Update config file 
        my $config = Utils::read_config_file("$root/$CONFIG");
        $config->{$CONFIG_VID} = $vid; 
        Utils::write_config_file("$root/$CONFIG", $config);
    }
}

=pod

=head1 SEE ALSO

All valid project_ids are listed in F<Project.pm> and all constants are defined 
in F<Constants.pm>.

=cut
