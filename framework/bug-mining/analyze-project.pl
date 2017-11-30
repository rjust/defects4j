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

analyze-project.pl -- Set up project and determine all suitable revision pairs
                      from the commit-db.

=head1 SYNOPSIS

analyze-project.pl -p project_id -w work_dir [ -v version_id]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the project for which the version pairs are analyzed.

=item B<-w C<work_dir>>

Use C<work_dir> as the working directory.

=item B<-v C<version_id>>

Only analyze this version id or interval of version ids (optional).
The version_id has to have the format B<(\d+)(:(\d+))?> -- if an interval is
provided, the interval boundaries are included in the analysis.
Per default all version ids are considered.

=back

=head1 DESCRIPTION

Runs the following worflow for all versions in the project's
C<commit-db>, or (if -v is specified) for a subset of versions:


=over 4

=item 1) Verify that src diff (rev2 -> rev1) is not empty.

=item 2) Export non-empty src and test diff to F<C<work_dir>/"project_id"/patches>.
         Only exported if it does not exist. Exported files are named F<$vid.src.patch> and
         F<$vid.test.patch> for source and test diffs, accordingly.

=item 3) Checkout fixed revision

=item 4) Compile src and test

=item 5) Run tests and log failing tests to F<C<work_dir>/"project_id"/failing_tests>

=item 6) Exclude failing tests, recompile and rerun. This will be repeated until there are
         no more failing tests in F<$TEST_RUNS> consecutive executions.
         (Maximum limit of looping in this phase is specified by F<$MAX_TEST_RUNS>)

=item 6) Checkout fixed version

=item 7) Apply src patch (fixed -> buggy)

=item 8) Compile src and test

=back

The result for each individual step is stored in F<C<work_dir>/$TAB_REV_PAIRS>

For each steps the output table contains a column, indicating the result of the
the step or '-' if the step was not applicable.

=cut

use warnings;
use strict;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;
use Project;
use DB;
use Utils;

############################## ARGUMENT PARSING
my %cmd_opts;
getopts('p:v:w:', \%cmd_opts) or pod2usage(1);

my ($PID, $VID, $WORK_DIR) =
    ($cmd_opts{p},
     $cmd_opts{v},
     $cmd_opts{w}
    );

pod2usage(1) unless defined $PID and defined $WORK_DIR; # $VID can be undefined

$WORK_DIR = abs_path($WORK_DIR);

# TODO make output dir more flexible
my $db_dir = $WORK_DIR;

# Check format of target version id
if (defined $VID) {
    $VID =~ /^(\d+)(:(\d+))?$/ or die "Wrong version id format ((\\d+)(:(\\d+))?): $VID!";
}

############################### VARIABLE SETUP
# Number of successful test runs in a row required
my $TEST_RUNS=2;
# Number of maximum test runs (give up point)
my $MAX_TEST_RUNS=10;

# Temporary directory
my $TMP_DIR = Utils::get_tmp_dir();
system("mkdir -p $TMP_DIR");
# Set up project
my $project = Project::create_project($PID, $WORK_DIR, "$WORK_DIR/$PID/commit-db", "$WORK_DIR/$PID/$PID.build.xml");
$project->{prog_root} = $TMP_DIR;

# Get database handle for results
my $dbh = DB::get_db_handle($TAB_REV_PAIRS, $db_dir);
my @COLS = DB::get_tab_columns($TAB_REV_PAIRS) or die;

# Set up directory for src and test patches
my $PATCH_DIR = "$WORK_DIR/$PID/patches";
system("mkdir -p $PATCH_DIR");

# Directory for patches already minimized manually
my $MINIMIZED_PATCHES = "$SCRIPT_DIR/minimized-patches/$PID";

# Set up directory for failing tests
my $FAIL_DIR = "$WORK_DIR/$PID/failing_tests";
system("mkdir -p $FAIL_DIR");


############################### MAIN LOOP
# figure out which IDs to run script for
my @ids = $project->get_version_ids();
if (defined $VID) {
    if ($VID =~ /(\d+):(\d+)/) {
        @ids = grep { ($1 <= $_) && ($_ <= $2) } @ids;
    } else {
        # single vid
        @ids = grep { ($VID == $_) } @ids;
    }
}

my $sth = $dbh->prepare("SELECT * FROM $TAB_REV_PAIRS WHERE $PROJECT=? AND $ID=?") or die $dbh->errstr;
foreach my $vid (@ids) {
    # Skip existing entries
    $sth->execute($PID, $vid);
    next if $sth->rows !=0;

    printf ("%4d: $project->{prog_name}\n", $vid);

    my %data;
    $data{$PROJECT} = $PID;
    $data{$ID} = $vid;

    _check_diff($project, $vid, \%data) and
    _check_t2v2($project, $vid, \%data) and
    _check_t2v1($project, $vid, \%data);

    # Add data set to result file
    _add_row(\%data);
}
$dbh->disconnect();
system("rm -rf $TMP_DIR");

############################### SUBROUTINES
# Check size of src diff and export patch file if size > 0.
# Returns 1 on success, 0 otherwise
sub _check_diff {
    my ($project, $vid, $data) = @_;

    # Lookup revision ids
    my $v1  = $project->lookup("${vid}b");
    my $v2  = $project->lookup("${vid}f");

    # Lookup src and test directory for v2
    my $src  = $project->src_dir($v2);
    my $test = $project->test_dir($v2);

    # Determine patch size for src and test patches (rev2 -> rev1)
    my $minimized_patch_test = "$MINIMIZED_PATCHES/$v2-$v1.test.patch";
    my $minimized_patch_src = "$MINIMIZED_PATCHES/$v2-$v1.src.patch";

    my $diff;
    if (-e $minimized_patch_test) {
        $diff = _read_file($minimized_patch_test);
    } else {
        $diff = $project->diff($v2, $v1, $test);
    }
    die unless defined $diff;
    $data->{$DIFF_TEST} = scalar(split("\n", $diff));
    # Save test patch if it exists
    if ($data->{$DIFF_TEST} != 0) {
        # only write if patch does not already exist
        my $output_file = "$PATCH_DIR/$vid.test.patch";
        unless (-e $output_file) {
            open(OUT, ">$output_file") or die "Cannot write test diff: $!";
            print OUT $diff;
            close OUT;
        }
    }

    if (-e $minimized_patch_src) {
        $diff = _read_file($minimized_patch_src);
    } else {
        $diff = $project->diff($v2, $v1, $src);
    }
    die unless defined $diff;
    $data->{$DIFF_SRC} = scalar(split("\n", $diff)) or return 0;
    # Save src patch
    # only write if patch does not already exist
    my $output_file = "$PATCH_DIR/$vid.src.patch";
    unless (-e $output_file) {
        open(OUT, ">$output_file") or die "Cannot write src diff: $!";
        print OUT $diff;
        close OUT;
    }
    return 1;
}

sub _read_file {
    my $fn = shift;
    open FH, $fn or die "could not open file: $!\n";
    my @lines = <FH>;
    return join('', @lines);
}

# Check whether v2 and t2 can be compiled and export failing tests.
# Returns 1 on success, 0 otherwise
sub _check_t2v2 {
    my ($project, $vid, $data) = @_;

    # Lookup revision ids
    my $v1  = $project->lookup("${vid}b");
    my $v2  = $project->lookup("${vid}f");

    # Checkout v2
    $project->checkout_vid("${vid}f", $TMP_DIR, 1) == 1 or die;

    # Compile v2 ant t2
    my $ret = $project->compile();
    _add_bool_result($data, $COMP_V2, $ret) or return 0;
    $ret = $project->compile_tests();
    _add_bool_result($data, $COMP_T2V2, $ret) or return 0;

    # Clean previous results
    ` >$FAIL_DIR/$v2` if -e "$FAIL_DIR/$v2";
    my $successful_runs = 0;
    my $run = 1;
    while ($successful_runs < $TEST_RUNS && $run <= $MAX_TEST_RUNS) {
        # Automatically fix broken tests and recompile
        $project->fix_tests("${vid}f");
        $project->compile_tests() == 0 or die;

        # Run t2 and get number of failing tests
        my $file = "$project->{prog_root}/v2.fail"; `>$file`;
        $project->run_tests($file) == 0 or die;
        # Get number of failing tests
        my $list = Utils::get_failing_tests($file);
        my $fail = scalar(@{$list->{"classes"}}) + scalar(@{$list->{"methods"}});

        if ($run == 1) {
            $data->{$FAIL_T2V2} = $fail;
        } else {
            $data->{$FAIL_T2V2} += $fail;
        }

        ++$successful_runs;

        # Append to log if there were (new) failing tests
        unless ($fail == 0) {
            open(OUT, ">>$FAIL_DIR/$v2") or die "Cannot write failing tests: $!";
            print OUT "## $project->{prog_name}: $v2 ##\n";
            close OUT;
            system("cat $file >> $FAIL_DIR/$v2");
            $successful_runs = 0;
        }
        ++$run;
    }
    return 1;
}

# Check whether t2 and v1 can be compiled
sub _check_t2v1 {
    my ($project, $vid, $data) = @_;

    # Lookup revision ids
    my $v1  = $project->lookup("${vid}b");
    my $v2  = $project->lookup("${vid}f");

    # Checkout v2
    $project->checkout_vid("${vid}f", $TMP_DIR, 1) == 1 or die;

    # Lookup src directory for v2
    my $src = $project->src_dir($v2);

    # Apply src patch v2 -> v1
    $project->apply_patch($project->{prog_root}, "$PATCH_DIR/$vid.src.patch", $src) == 0 or die;

    # Compile v1 and t2v1
    my $ret = $project->compile();
    _add_bool_result($data, $COMP_V1, $ret) or return;
    $ret = $project->compile_tests();
    _add_bool_result($data, $COMP_T2V1, $ret);
}

# Convert return code into boolean value and set key in data hash
sub _add_bool_result {
    my ($data, $key, $ret_code) = @_;
    $data->{$key} = ($ret_code==0 ? 1 : 0);
}

# Add a row to the database table
sub _add_row {
    my $data = shift;

    my @tmp;
    foreach (@COLS) {
        push (@tmp, $dbh->quote((defined $data->{$_} ? $data->{$_} : "-")));
    }

    my $row = join(",", @tmp);
    $dbh->do("INSERT INTO $TAB_REV_PAIRS VALUES ($row)");
}

=pod

=head1 SEE ALSO

All valid C<project_id>s are listed in F<Project.pm>
To achieve workflow, after this script manually verify that all test failures are valid
and not spurious, broken, random, or due to classpath issues.

Next step in workflow: F<get-trigger.pl>
=cut
