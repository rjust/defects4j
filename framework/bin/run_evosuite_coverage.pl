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

run_evosuite_coverage.pl -- generates EvoSuite coverage reports for generated test suites.

=head1 SYNOPSIS

  run_evosuite_coverage.pl -p project_id -d suite_dir -o out_dir -c criterion [-f include_file_pattern] [-v version_id] [-t tmp_dir] [-D] [-A]

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

=item -c C<criterion>
Criterion to use in measuring coverage. 
See below for supported test criteria.

=item -f C<include_file_pattern>

The pattern of the file names of the test classes that should be included (optional).
Per default all files (*.java) are included.

=item -t F<tmp_dir>

The temporary root directory to be used to check out program versions (optional).
The default is F</tmp>.

=item -D

Debug: Enable verbose logging and do not delete the temporary check-out directory
(optional).

=item -A

All relevant classes: Measure code coverage for all relevant classes (i.e., all
classes touched by the triggering tests). By default code coverage is measured
only for classes modified by the bug fix.

=back

=cut
my %criteria = ( branch,
                 weakmutation,
                 strongmutation,
                 onlymutation,
                 defuse,
                 cbranch,
                 ibranch,
                 statement,
                 rho,
                 ambiguitiy,
                 alldefs,
                 exception,
                 regression,
                 readability,
                 onlybranch,
                 methodtrace,
                 method,
                 methodnoexception,
                 onlyline,
                 line,
                 output,
                 input,
                 trycatch,
                 default,
                 "branch:line",
                 "branch:line:cbranch",
                 "branch:line:cbranch:weakmutation",
                 "branch:line:cbranch:weakmutation:method",
                 "branch:cbranch",
                 "branch:weakmutation",
                 "branch:weakmutation:cbranch",
                 "branch:weakmutation:cbranch:exception",
                 "cbranch:branch:line:weakmutation:output",
                 "branch:exception",
                 "branch:exception:cbranch",
                 "branch:weakmutation",
                 "branch:weakmutation:method",
                 "branch:output",
                 "branch:output:line",
                 "branch:output:line:weakmutation",
                 "branch:weakmutation:line",
                 "cbranch:weakmutation"
               );

=pod

=head1 DESCRIPTION

Generates the EvoSuite coverage report for each provided test suite (i.e., each test suite archive in
F<suite_dir>) on the program version for which that test suite was generated and the chosen criterion.

=cut
use warnings;
use strict;


use FindBin;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;
use File::Find;

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Coverage;
use Project;
use Utils;
use Log;
use DB;

#
# Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('p:d:t:o:c:f:DA', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{d} and defined $cmd_opts{o} and defined $cmd_opts{c};

# Ensure that directory of test suites exists
-d $cmd_opts{d} or die "Test suite directory $cmd_opts{d} does not exist!";

my $PID = $cmd_opts{p};
my $SUITE_DIR = abs_path($cmd_opts{d});
my $INCL = $cmd_opts{f} // "*.java";
# Enable debugging if flag is set
$DEBUG = 1 if defined $cmd_opts{D};
my $CRITERION = $cmd_opts{c};

# Set up project
my $project = Project::create_project($PID);

# Output directory for results
system("mkdir -p $cmd_opts{o}");
my $OUT_DIR = abs_path($cmd_opts{o});

# Temporary directory for execution
my $TMP_DIR = Utils::get_tmp_dir($cmd_opts{t});
system("mkdir -p $TMP_DIR");

=pod

=head2 Logging

By default, the script logs all errors and warnings to run_coverage.pl.log in
the temporary project root.
Upon success, the log file of this script and the detailed coverage results for
each executed test suite are copied to:
F<out_dir/L<TAB_COVERAGE|DB>_log/project_id>.

=cut
# Log directory and file
my $LOG_DIR = "$OUT_DIR/${TAB_COVERAGE}_log/$PID";
my $LOG_FILE = "$LOG_DIR/" . basename($0) . ".log";
system("mkdir -p $LOG_DIR");

# Open temporary log file
my $LOG = Log::create_log("$TMP_DIR/". basename($0) . ".log");
$LOG->log_time("Start code coverage analysis");

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
my $test_suites = Utils::get_all_test_suites($SUITE_DIR, $PID);

# Directory of class lists used for instrumentation step
my $CLASSES = defined $cmd_opts{A} ? "loaded_classes" : "modified_classes";
my $TARGET_CLASSES_DIR = "$SCRIPT_DIR/projects/$PID/$CLASSES";

# Iterate over all version ids
foreach my $vid (keys %{$test_suites}) {

    # Iterate over all test suite sources (test data generation tools)
    foreach my $suite_src (keys %{$test_suites->{$vid}}) {
        `mkdir -p $LOG_DIR/$suite_src`;

        # Iterate over all test suites for this source
        foreach my $test_id (keys %{$test_suites->{$vid}->{$suite_src}}) {
            my $archive = $test_suites->{$vid}->{$suite_src}->{$test_id};
            my $test_dir = "$TMP_DIR/$suite_src";

            $LOG->log_msg(" - Executing test suite: $archive");
            printf ("Executing test suite: $archive\n");

            # Extract generated tests into temp directory
            Utils::extract_test_suite("$SUITE_DIR/$archive", $test_dir)
                or die "Cannot extract test suite!";

            #
            # Run the actual code coverage analysis
            #
            _run_coverage($vid, $suite_src, $test_id, $test_dir, $CRITERION);
        }
    }
}
# Log current time
$LOG->log_time("End code coverage analysis");
$LOG->close();

# Copy log file and clean up temporary directory
system("cat $LOG->{file_name} >> $LOG_FILE") == 0 or die "Cannot copy log file";
#system("rm -rf $TMP_DIR") unless $DEBUG;

#
# Run code coverage analysis on the program version for which the tests were created.
#
sub _run_coverage {
    my ($vid, $suite_src, $test_id, $test_dir, $criterion) = @_;

    # Get archive name for current test suite
    my $archive = $test_suites->{$vid}->{$suite_src}->{$test_id};

    my $result = Utils::check_vid($vid);
    my $bid   = $result->{bid};
    my $type  = $result->{type};

    # Run on fixed version

    # Checkout program version
    my $root = "$TMP_DIR/V_fixed";
    $LOG->log_msg("Starting code coverage on fixed version");
    $project->{prog_root} = "$root";
    $project->checkout_vid("${bid}f") or die "Checkout failed";

    # Compile the program version
    $project->compile() or die "Compilation failed for fixed version";

    # Compile tests. This ensures that all necessary folders are on classpath.
    #$project->compile_tests() or die "Test compilation failed for fixed version";

    # Compile generated tests
    if(! $project->compile_ext_tests($test_dir)) {
        $LOG->log_msg("Tests do not compile on fixed version!");
        return undef;
    }
    my $src_dir = $project->src_dir($vid);

    # List of target classes
    my $target_classes = "$SCRIPT_DIR/projects/$PID/$CLASSES/$bid.src";
    open(LIST, "<$target_classes") or die "Could not open list of target classes $target_classes: $!";
    my @classes = <LIST>;
    close(LIST);

    #Call EvoSuite and generate reports
    my $cp_file = "$project->{prog_root}/project.cp";
    $project->_ant_call("export.cp.test", "-Dfile.export=$cp_file");
    my $cp = `cat $cp_file` .
             ":$LIB_DIR/test_generation/runtime/evosuite-rt.jar";
    my $gen_test_dir = "";
    find(sub {$gen_test_dir = $File::Find::name if /gen-tests/}, $project->{prog_root});
    if($gen_test_dir ne ""){
        $cp = $cp . ":" . $gen_test_dir;
    }
    # Make sure all entries in class path exist.
    my @cp_entries = split /:/, $cp;
    my $edited_cp = "";
    foreach my $entry (@cp_entries) {
        if(-e $entry){
            $edited_cp = $edited_cp .
                         ":" .
                         $entry;
        }else{
            $LOG->log_msg("entry: $entry does not exist.");
        }
    }
    $cp = substr $edited_cp, 1;
    $LOG->log_msg("classpath: $cp");


    foreach my $class (@classes) {
        my $cmd = "";
        if ($criterion eq "default") {
            $cmd = "java -cp $TESTGEN_LIB_DIR/evosuite-1.0.4.jar org.evosuite.EvoSuite " .
                        "-measureCoverage ".
                        "-class $class " .
                        "-Djunit=$gen_test_dir " .
                        "-projectCP $cp " .
                        "-base_dir $project->{prog_root} " .
                        "-Dcoverage_matrix=true " .
                        "-mem 3000";
        } else {
            $cmd = "java -cp $TESTGEN_LIB_DIR/evosuite-1.0.4.jar org.evosuite.EvoSuite " .
                        "-measureCoverage ".
                        "-criterion $criterion " .
                        "-class $class " .
                        "-Djunit=$gen_test_dir " .
                        "-projectCP $cp " .
                        "-base_dir $project->{prog_root} " .
                        "-Dcoverage_matrix=true " .
                        "-mem 3000";
        }
        $cmd =~ s/\R//g;

        my $log;
        Utils::exec_cmd($cmd, "EvoSuite coverage log generation ($criterion)", \$log);
        system("rm -rf evosuite-report");
        $LOG->log_msg($log);
    }
    #Clean up and store results
    system("mv $project->{prog_root}/evosuite-report/ $LOG_DIR/$suite_src/${bid}f");

    # Run on buggy version

    # Checkout program version
    $root = "$TMP_DIR/V_buggy";
    $LOG->log_msg("Starting code coverage on buggy version");
    $project->{prog_root} = "$root";
    $project->checkout_vid("${bid}b") or die "Checkout failed";

    # Compile the program version
    $project->compile() or die "Compilation failed for buggy version";
    #$project->compile_tests() or die "Test compilation failed for buggy version";

    # Compile generated tests
    if(! $project->compile_ext_tests($test_dir)) {
        $LOG->log_msg("Tests do not compile on buggy version!");
        return undef;
    }
    $src_dir = $project->src_dir($vid);

    # List of target classes
    $target_classes = "$SCRIPT_DIR/projects/$PID/$CLASSES/$bid.src";
    open(LIST, "<$target_classes") or die "Could not open list of target classes $target_classes: $!";
    @classes = <LIST>;
    close(LIST);

    #Call EvoSuite and generate reports
    $cp_file = "$project->{prog_root}/project.cp";
    $project->_ant_call("export.cp.test", "-Dfile.export=$cp_file");
    $cp = `cat $cp_file` .
             ":$LIB_DIR/test_generation/runtime/evosuite-rt.jar";
    $gen_test_dir = "";
    find(sub {$gen_test_dir = $File::Find::name if /gen-tests/}, $project->{prog_root});
    if($gen_test_dir ne ""){
        $cp = $cp . ":" . $gen_test_dir;
    }    
    # Make sure all entries in class path exist.
    @cp_entries = split /:/, $cp;
    $edited_cp = "";
    foreach my $entry (@cp_entries) {
        if(-e $entry){
            $edited_cp = $edited_cp .
                         ":" .
                         $entry;
        }else{
            $LOG->log_msg("entry: $entry does not exist.");
        }
    }
    $cp = substr $edited_cp, 1;
    $LOG->log_msg("classpath: $cp");

    foreach my $class (@classes) {
        my $cmd = "";
        if ($criterion eq "default") {
            $cmd = "java -cp $TESTGEN_LIB_DIR/evosuite-1.0.4.jar org.evosuite.EvoSuite " .
                        "-measureCoverage ".
                        "-class $class " .
                        "-Djunit=$gen_test_dir " .
                        "-projectCP $cp " .
                        "-base_dir $project->{prog_root} " .
                        "-Dcoverage_matrix=true " .
                        "-mem 3000";
        } else {
            $cmd = "java -cp $TESTGEN_LIB_DIR/evosuite-1.0.4.jar org.evosuite.EvoSuite " .
                        "-measureCoverage ".
                        "-criterion $criterion " .
                        "-Djunit=$gen_test_dir " .
                        "-class $class " .
                        "-projectCP $cp " .
                        "-base_dir $project->{prog_root} " .
                        "-Dcoverage_matrix=true " .
                        "-mem 3000";
        }
        $cmd =~ s/\R//g;

        my $log;
        Utils::exec_cmd($cmd, "EvoSuite coverage log generation ($criterion)", \$log);
        system("rm -rf evosuite-report");
        $LOG->log_msg($log);
    }
    #Clean up and store results
    system("mv $project->{prog_root}/evosuite-report/ $LOG_DIR/$suite_src/${bid}b");

}
