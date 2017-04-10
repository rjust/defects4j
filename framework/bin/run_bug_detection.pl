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

run_bug_detection.pl -- bug detection analysis for generated test suites.

=head1 SYNOPSIS

  run_bug_detection.pl -p project_id -d suite_dir -o out_dir [-f include_file_pattern] [-v version_id] [-t tmp_dir] [-D]

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

=item -D

Debug: Enable verbose logging and do not delete the temporary check-out directory
(optional).

=back

=head1 DESCRIPTION

Runs the following worflow for each provided test suite (i.e., each test suite
archive in F<suite_dir>):

=over 4

=item 1) Verify that test suite compiles and runs on the version it was
         generated for (i.e., the buggy or fixed version).

=item 2) Run test suite on the opposite version and determine whether it fails
         (a test suite generated for a buggy version is executed on the fixed
         version, and a test suite generated for a fixed version is executed on
         the buggy version).

=item 3) Determine the number of triggering tests.

=back

The results of the analysis are stored in the database table
F<out_dir/L<TAB_BUG_DETECTION|DB>>. The corresponding log files are stored in
F<out_dir/L<TAB_BUG_DETECTION|DB>_log>.

For each step the database table contains a column, indicating the result of the step or
'-' if the step was not applicable. B<Note that the workflow is interrupted as soon as one
of the steps fails and the script continues with the next test suite>.

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

# Cache column names for table bug_detection
my @COLS = DB::get_tab_columns($TAB_BUG_DETECTION) or die "Cannot obtain table columns!";

=pod

=head2 Logging

By default, the script logs all errors and warnings to run_bug_detection.pl.log in
the temporary project root.
Upon success, the log file of this script and the detailed bug detection results for
each executed test suite are copied to:
F<out_dir/L<TAB_BUG_DETECTION|DB>_log/project_id>.

=cut
# Log directory and file
my $LOG_DIR = "$OUT_DIR/${TAB_BUG_DETECTION}_log/$PID";
my $LOG_FILE = "$LOG_DIR/" . basename($0) . ".log";
system("mkdir -p $LOG_DIR");

# Open temporary log file
my $LOG = Log::create_log("$TMP_DIR/". basename($0) . ".log");
$LOG->log_time("Start executing test suites");

=pod

=head2 Test Suites

To be considered for the analysis, a test suite has to be provided as an archive in
F<suite_dir>. Format of the archive file name:

C<project_id-version_id-test_suite_src(\.test_id)?\.tar\.bz2>

Note that C<test_id> is optional, the default is 1.

Examples:

=over 4

=item * F<Lang-11f-randoop.1.tar.bz2 (equal to Lang-11f-randoop.tar.bz2)>

=item * F<Lang-11b-randoop.2.tar.bz2>

=item * F<Lang-12b-evosuite-weakmutation.1.tar.bz2>

=item * F<Lang-12f-evosuite-branch.1.tar.bz2>

=back

=cut

# Get all test suite archives that match the given project id and version id
my $test_suites = Utils::get_all_test_suites($SUITE_DIR, $PID, $VID);

# Get database handles for determining suitable version ids and for results
my $dbh_out = DB::get_db_handle($TAB_BUG_DETECTION, $OUT_DIR);

my $sth = $dbh_out->prepare("SELECT * FROM $TAB_BUG_DETECTION WHERE $PROJECT=? AND $TEST_SUITE=? AND $ID=? AND $TEST_ID=?")
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
            # Run tests on opposite version and determine test suite type
            #
            # Broken: Test suite could not be executed
            #
            # Fail: Test suite fails
            #
            # Pass: Test suite passes
            #
            my $failing = _run_tests($vid, $suite_src, $test_id, $test_dir);
            unless (defined $failing) {
                _insert_row($vid, $suite_src, $test_id, "Broken");
                next;
            }
            my $type = $failing > 0 ? "Fail" : "Pass";
            _insert_row($vid, $suite_src, $test_id, $type, $failing);

        }
    }
}
$dbh_out->disconnect();
# Log current time
$LOG->log_time("End executing test suites");
$LOG->close();

# Copy log file and clean up temporary directory
system("cat $LOG->{file_name} >> $LOG_FILE") == 0 or die "Cannot copy log file";
system("rm -rf $TMP_DIR") unless $DEBUG;


#
# Runs tests on opposite version and log failing tests
# Returns number of failing tests on success (i.e., tests compile and run),
# undef otherwise
#
sub _run_tests {
    my ($vid, $suite_src, $test_id, $test_dir) = @_;

    # Get archive name for current test suite
    my $archive = $test_suites->{$vid}->{$suite_src}->{$test_id};

    $vid =~ /^(\d+)([bf])$/ or die "Unexpected version id: $vid!";
    my $bid   = $1;
    my $type  = $2;

    # Hash that holds the number of failing tests for the fixed and buggy version
    my %failing_tests = (f=>0, b=>0);

#
# Run on fixed version
# TODO: Refactor common code for running the fixed and buggy version
#
    # Check out fixed version, and compile classes and tests
    my $root = "$TMP_DIR/V_fixed";
    $project->{prog_root} = $root;
    $project->checkout_vid("${bid}f");
    $project->compile() or die "Fixed version does not compile!";
    # Compile generated tests
    if (! $project->compile_ext_tests($test_dir)) {
        $LOG->log_msg(" - Tests do not compile on fixed version: $archive");
        return undef;
    }
    # Run generated tests and log results
    my $log = "$TMP_DIR/run_V_fixed.log"; `>$log`;
    if (! $project->run_ext_tests($test_dir, "$INCL", $log)) {
        $LOG->log_msg(" - Tests not executable on fixed version: $archive");
        return undef;
    }
    # Determine whether test suite passes or fails on fixed version and store
    # number of failing tests in hash {f} -> #failing tests
    my $list = Utils::get_failing_tests($log) or die;
    my $count = scalar(@{$list->{methods}}) + scalar(@{$list->{classes}});
    $failing_tests{f} = $count;
    # Log number of all failing test methods and classes
    $LOG->log_msg(" - Found $count failing tests on fixed version: $archive") if $count > 0;
    # Copy stack traces of triggering tests
    system("cp $log $LOG_DIR/$suite_src/${bid}f.$test_id.trigger.log") == 0
        or die "Cannot copy stack traces from triggering tests";

#
# Run on buggy version
#
    # Lookup src directory and patch
    my $patch_dir = "$SCRIPT_DIR/projects/$PID/patches";
    my $src_patch = "$patch_dir/$bid.src.patch";
    my $src_path =  $project->src_dir($vid);

    # Check out fixed version, apply src patch (fixed -> buggy), and compile classes and tests
    $root = "$TMP_DIR/V_buggy";
    $project->{prog_root} = $root;
    $project->checkout_vid("${bid}b");
    $project->compile() or die "Buggy version does not compile!";
    # Compile generated tests
    if (! $project->compile_ext_tests($test_dir)) {
        $LOG->log_msg(" - Tests do not compile on buggy version: $archive");
        return undef;
    }
    # Run generated tests and log results
    $log = "$TMP_DIR/run_V_buggy.log"; `>$log`;
    if (! $project->run_ext_tests($test_dir, "$INCL", $log)) {
        $LOG->log_msg(" - Tests not executable on buggy version: $archive");
        return undef;
    }
    # Determine whether test suite passes or fails on buggy version and store
    # number of failing tests in hash {b} -> #failing tests
    $list = Utils::get_failing_tests($log) or die;
    $count = scalar(@{$list->{methods}}) + scalar(@{$list->{classes}});
    $failing_tests{b} = $count;
    # Log number of all failing test methods and classes
    $LOG->log_msg(" - Found $count failing tests on buggy version: $archive") if $count > 0;
    # Copy stack traces of triggering tests
    system("cp $log $LOG_DIR/$suite_src/${bid}b.$test_id.trigger.log") == 0
        or die "Cannot copy stack traces from triggering tests";

    # Determine type of opposite version (f->b or b->f)
    my $target = ($type eq "f") ? "b" : "f";

    # Every test suite has to pass on the version it was generated for
    $failing_tests{$type} == 0 or return undef;

    # Return number of failing tests on opposite version
    return $failing_tests{$target};
}

#
# Insert row in database
#
# TODO: Extract the following subroutines as they belong in the core framework
#
sub _insert_row {
    @_ >= 4 or die $ARG_ERROR;
    my ($vid, $suite, $test_id, $type, $trigger) = @_;

    # Build data hash
    my $data = {
         $PROJECT => $PID,
         $ID => $vid,
         $TEST_SUITE => $suite,
         $TEST_ID => $test_id,
         $TEST_CLASS => $type,
         $NUM_TRIGGER => $trigger,
    };

    # Build row based on data hash
    my @tmp;
    foreach (@COLS) {
        push (@tmp, $dbh_out->quote((defined $data->{$_} ? $data->{$_} : "-")));
    }

    # Concat values and write to database table
    my $row = join(",", @tmp);

    $dbh_out->do("INSERT INTO $TAB_BUG_DETECTION VALUES ($row)");
}
