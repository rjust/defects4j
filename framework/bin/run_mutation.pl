#!/usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2017 René Just, Darioush Jalali, and Defects4J contributors.
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

run_mutation.pl -- mutation analysis for generated test suites.

=head1 SYNOPSIS

  run_mutation.pl -p project_id -d suite_dir -o out_dir [-f include_file_pattern] [-v version_id] [-t tmp_dir] [-e exclude_file] [-D] [-A]

=head1 OPTIONS

=over 4

=item -p C<project_id>

The id of the project for which the generated test suites are analyzed.
See L<Project|Project/"Available Project IDs"> module for available project IDs.

=item -d F<suite_dir>

The directory that contains the test suite archives.
See L<Test suites|/"Test suites">.

=item -o F<out_dir>

The output directory for the results and log files.

=item -f C<include_file_pattern>

The pattern of the file names of the test classes that should be included (optional).
Per default all files (*.java) are included.

=item -v C<version_id>

Only analyze test suites for this version id (optional). Per default all
test suites for the given project id are analyzed.

=item -t F<tmp_dir>

The temporary root directory to be used to check out program versions (optional).
The default is F</tmp>.

=item -e F<exclude_file>

The file that contains the list of all mutants ids (one per row) to exclude (optional).
Per default no exclude file is used and therefore no mutant is excluded.

=item -D

Debug: Enable verbose logging and do not delete the temporary check-out directory
(optional).

=item -A

All relevant classes: Perform mutation analysis for all relevant classes (i.e., all
classes touched by the triggering tests). By default only classes modified by
the bug fix are analyzed.

=back

=head1 DESCRIPTION

Performs mutation analysis for each provided test suite (i.e., each test suite
archive in F<suite_dir>) on the program version for which that test suite was generated.
B<Each test suite has to pass on the program version for which it was generated.>

The results of the analysis are stored in the database table
F<out_dir/L<TAB_MUTATION|DB>>. The corresponding log files are stored in
F<out_dir/L<TAB_MUTATION|DB>_log>.

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
getopts('p:d:v:t:o:f:e:DA', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{d} and defined $cmd_opts{o};

# Ensure that directory of test suites exists
-d $cmd_opts{d} or die "Test suite directory $cmd_opts{d} does not exist!";

my $PID = $cmd_opts{p};
my $SUITE_DIR = abs_path($cmd_opts{d});
my $VID = $cmd_opts{v} if defined $cmd_opts{v};
my $INCL = $cmd_opts{f} // "*.java";
my $EXCL = $cmd_opts{e};
# Enable debugging if flag is set
$DEBUG = 1 if defined $cmd_opts{D};

# The mutation operators that should be enabled
my @MUT_OPS = ("AOR", "LOR","SOR", "COR", "ROR", "ORU", "LVR", "STD");

# Set up project
my $project = Project::create_project($PID);

# Check format of target version id
if (defined $VID) {
    # Verify that the provided version id is valid
    Utils::check_vid($VID);
    $project->contains_version_id($VID) or die "Version id ($VID) does not exist in project: $PID";
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
F<out_dir/L<TAB_MUTATION|DB>_log/project_id>.

=cut
# Log directory and file
my $LOG_DIR = "$OUT_DIR/${TAB_MUTATION}_log/$PID";
my $LOG_FILE = "$LOG_DIR/" . basename($0) . ".log";
system("mkdir -p $LOG_DIR");

# Open temporary log file
my $LOG = Log::create_log("$TMP_DIR/". basename($0) . ".log");
$LOG->log_time("Start mutation analysis");

=pod

=head2 Test suites

To be considered for the analysis, a test suite has to be provided as an archive in
F<suite_dir>. Format of the archive file name:

C<project_id-version_id-test_suite_src(\.test_id)?\.tar\.bz2>

Note that C<test_id> is optional, the default is 1.

Examples:

=over 4

=item * F<Lang-11f-randoop.1.tar.bz2 (equal to Lang-1-randoop.tar.bz2)>

=item * F<Lang-11b-randoop.2.tar.bz2>

=item * F<Lang-12b-evosuite-weakmutation.1.tar.bz2>

=item * F<Lang-12f-evosuite-branch.1.tar.bz2>

=back

=cut

# Get all test suite archives that match the given project id and version id
my $test_suites = Utils::get_all_test_suites($SUITE_DIR, $PID, $VID);

# Directory of class lists used for mutation step
my $CLASSES = defined $cmd_opts{A} ? "loaded_classes" : "modified_classes";
my $TARGET_CLASSES_DIR = "$SCRIPT_DIR/projects/$PID/$CLASSES";

# Get database handle for result table
my $dbh_out = DB::get_db_handle($TAB_MUTATION, $OUT_DIR);

my $sth = $dbh_out->prepare("SELECT * FROM $TAB_MUTATION WHERE $PROJECT=? AND $TEST_SUITE=? AND $ID=? AND $TEST_ID=?")
    or die $dbh_out->errstr;

# Iterate over all version ids
foreach my $vid (keys %{$test_suites}) {

    # Iterate over all test suite sources (test data generation tools)
    foreach my $suite_src (keys %{$test_suites->{$vid}}) {
        `mkdir -p $LOG_DIR/$suite_src`;

        # Iterate over all test suites for this source
        foreach my $test_id (keys %{$test_suites->{$vid}->{$suite_src}}) {
            my $archive = $test_suites->{$vid}->{$suite_src}->{$test_id};
            my $test_dir = "$TMP_DIR/$suite_src";

            # Skip existing entries
            $sth->execute($PID, $suite_src, $vid, $test_id);
            if ($sth->rows !=0) {
                $LOG->log_msg(" - Skipping $archive since results already exist in database!");
                next;
            }

            $LOG->log_msg(" - Executing test suite: $archive");
            printf ("Executing test suite: $archive\n");

            # Extract generated tests into temp directory
            Utils::extract_test_suite("$SUITE_DIR/$archive", $test_dir)
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
    my $archive = $test_suites->{$vid}->{$suite_src}->{$test_id};

    my $result = Utils::check_vid($vid);
    my $bid   = $result->{bid};
    my $type  = $result->{type};

    # Checkout program version
    my $root = "$TMP_DIR/${vid}";
    $project->{prog_root} = "$root";
    $project->checkout_vid($vid) or die "Checkout failed";

    my $num_excluded_mutants = 0;
    if (defined $EXCL) {
      # Count number of excluded mutants: number of lines, excluding:
      #   - empty lines, i.e., lines with only spaces or tabs, or truly empty lines
      #   - lines with comments, i.e., lines that start with '#'
      open(EXCL_FILE, "<$EXCL") or die "Cannot read exclude file";
      while (<EXCL_FILE>) {
        next if /^[[:space:]]*(#.*)?$/;
        $num_excluded_mutants += 1;
      }
      close(EXCL_FILE);
    }

    my $gen_mutants = $project->mutate("$TARGET_CLASSES_DIR/$bid.src", \@MUT_OPS);
    $gen_mutants > 0 or die "No mutants generated for $vid!";

    # Compile generated tests
    $project->compile_ext_tests($test_dir) or die "Tests do not compile!";

    # No need to run the test suite first. Major's preprocessing verifies that
    # all tests in the test suite pass before performing the mutation analysis.
    my $mut_log = "$TMP_DIR/.mutation.log"; `>$mut_log`;
    my $mut_map = Mutation::mutation_analysis_ext($project, $test_dir, "$INCL", $mut_log, $EXCL);
    if (defined $mut_map) {
        # Add results to database table
        Mutation::insert_row($OUT_DIR, $PID, $vid, $suite_src, $test_id, $gen_mutants, $num_excluded_mutants, $mut_map);
    } else {
        # Add incomplete results to database table to indicate a broken test suite
        Mutation::insert_row($OUT_DIR, $PID, $vid, $suite_src, $test_id, "-");
        $LOG->log_file(" - Mutation analysis failed: $archive", $mut_log);
    }
    Mutation::copy_mutation_logs($project, $vid, $suite_src, $test_id, $mut_log, $LOG_DIR);
}
