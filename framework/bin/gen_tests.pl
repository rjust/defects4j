#!/usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2024 René Just, Darioush Jalali, and Defects4J contributors.
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

gen_tests.pl -- generate a test suite using one of the supported test generators.

=head1 SYNOPSIS

  gen_tests.pl -g generator -p project_id -v version_id -n test_id -o out_dir -b total_budget [-c target_classes] [-s random_seed] [-t tmp_dir] [-E] [-D]

=head1 OPTIONS

=over 4

=item -g C<generator>

The test generator to use. Run the following command to see a list of supported
test generators: C<gen_tests.pl -g help>

=item -p C<project_id>

Generate tests for this project id.
See L<Project|Project/"Available Project IDs"> module for available project IDs.

=item -v C<version_id>

Generate tests for this version id.
Format: C<\d+[bf]>.

=item -n C<test_id>

The id of the generated test suite (i.e., which run of the same configuration).

=item -o F<out_dir>

The root output directory for the generated test suite. The test suite and logs are
written to:
F<out_dir/project_id/version_id>.

=item -b C<total_budget>

The total time in seconds allowed for test generation.

=item -c F<classes_file>

The file that lists all classes the test generator should target, one class per
line (optional).  By default, tests are generated only for classes modified by
the bug fix.

=item -s C<random_seed>

The random seed used for test generation (optional). By default, the random seed
is computed as: <test_id> * 1000 + <bug_id>.

=item -t F<tmp_dir>

The temporary root directory to be used to check out the program version (optional).
The default is F</tmp>.

=item -E

Generate error-revealing (as opposed to regression) tests (optional).
By default this script generates regression tests, regardless of whether the
project version is a buggy or a fixed project version.
Note that not all test generators support both modes (i.e., generating
regression tests and generating error-revealing tests).

=item -D

Debug: Enable verbose logging and do not delete the temporary check-out directory
(optional).

=back

=head1 DESCRIPTION

This script runs the specified test generator on a particular program version.
Tests are, by default, generated for all classes modified by the bug fix; a set
of target classes can be specified using the C<-c> flag.

=head2 Tool configuration

The following wrapper script invokes the specified test generator and provides
the generator-specific configuration:
F<C<TESTGEN_BIN_DIR>/C<generator>.sh>.

=head2 Test suites

The source files of the generated test suite are compressed into an archive with
the following name:
F<C<project_id>-C<version_id>-C<generator>.C<test_id>.tar.bz2>

Examples:

=over 4

=item * F<Lang-12b-randoop.1.tar.bz2>

=item * F<Lang-12f-randoop.2.tar.bz2>

=item * F<Lang-12f-evosuite.1.tar.bz2>

=back

The test suite archive is written to:
F<out_dir/C<project_id>/C<generator>/C<test_id>>

=cut


use strict;
use warnings;

use FindBin;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Utils;
use Project;
use Log;

#
# Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('g:p:v:o:n:b:c:s:t:ED', \%cmd_opts) or pod2usage(1);
my $TOOL = $cmd_opts{g};
# Print all supported generators, regardless of the other arguments, if -g help
# is set
defined $TOOL and $TOOL =~ /^help$/ and is_generator_valid($TOOL) || exit 1;

pod2usage(1) unless defined $cmd_opts{g} and
                    defined $cmd_opts{p} and
                    defined $cmd_opts{v} and
                    defined $cmd_opts{n} and
                    defined $cmd_opts{b} and
                    defined $cmd_opts{o};

# Check whether the requested test generator is valid
is_generator_valid($TOOL) || exit 1;

my $PID = $cmd_opts{p};
# Instantiate project
my $project = Project::create_project($PID);

my $VID = $cmd_opts{v};
# Verify that the provided version id is valid
my $BID = Utils::check_vid($VID)->{bid};
$project->contains_version_id($VID) or die "Version id ($VID) does not exist in project: $PID";

# Verify that the provided test id is valid
my $TID = $cmd_opts{n};
$TID =~ /^\d+$/ or die "Wrong test_id format (\\d+): $TID!";

# Verify that the provided time budget is valid
my $TIME = $cmd_opts{b};
$TIME =~ /^\d+$/ or die "Wrong budget format (\\d+): $TIME!";

my $OUT_DIR = $cmd_opts{o};

# Set or compute the random seed
my $SEED = $cmd_opts{s} // $TID*1000 + $BID;

# List of target classes (list of modified classes is the default)
my $TARGET_CLASSES = $cmd_opts{c} // "$SCRIPT_DIR/projects/$PID/modified_classes/$BID.src";

# Generate regression tests by default
my $MODE = (defined $cmd_opts{E}) ? "error-revealing" : "regression";

# Enable debugging if flag is set
$DEBUG = 1 if defined $cmd_opts{D};

if ($DEBUG) {
  Utils::print_env();
}

# Temporary directory for project checkout
my $TMP_DIR = Utils::get_tmp_dir($cmd_opts{t});
system("mkdir -p $TMP_DIR");

# Set working directory
$project->{prog_root} = $TMP_DIR;

=pod

=head2 Logging

By default, the script logs all errors and warnings to F<gen_tests.log> in
the temporary project root.
Upon success, the log of this script is appended to:
F<out_dir/logs/C<project_id>.C<version_id>.log>.

=cut

# Log file in output directory
my $LOG_DIR = "$OUT_DIR/logs";
my $LOG_FILE = "$LOG_DIR/$PID.$VID.log";
system("mkdir -p $LOG_DIR");

# Checkout and compile project
$project->checkout_vid($VID) or die "Cannot checkout!";
$project->compile() or die "Cannot compile!";

# Open temporary log file
my $LOG = Log::create_log("$TMP_DIR/$PID.$VID.$TID.log");
$LOG->log_time("Start test generation");
$LOG->log_msg("Mode: $MODE");
$LOG->log_msg("Parameters:");
$LOG->log_msg(" -g $TOOL");
$LOG->log_msg(" -p $PID");
$LOG->log_msg(" -v $VID");
$LOG->log_msg(" -n $TID");
$LOG->log_msg(" -b $TIME");
$LOG->log_msg(" -c $TARGET_CLASSES");
$LOG->log_msg(" -s $SEED");

# Export all environment variables that are expected by the wrapper script of
# the test generator.
$ENV{D4J_HOME}                = "$BASE_DIR";
$ENV{D4J_FILE_TARGET_CLASSES} = "$TARGET_CLASSES";
$ENV{D4J_DIR_WORKDIR}         = "$TMP_DIR";
$ENV{D4J_DIR_OUTPUT}          = "$TMP_DIR/$TOOL";
$ENV{D4J_DIR_LOG}             = "$LOG_DIR";
$ENV{D4J_DIR_TESTGEN_BIN}     = "$TESTGEN_BIN_DIR";
$ENV{D4J_DIR_TESTGEN_LIB}     = "$TESTGEN_LIB_DIR";
$ENV{D4J_TOTAL_BUDGET}        = "$TIME";
$ENV{D4J_SEED}                = "$SEED";
$ENV{D4J_TEST_MODE}           = "$MODE";
$ENV{D4J_DEBUG}               = "$DEBUG";

# Create temporary output directory
Utils::exec_cmd("mkdir -p $TMP_DIR/$TOOL", "Creating temporary output directory")
        or die("Failed to create temporary output directory!");

# Invoke the test generator
Utils::exec_cmd("$TESTGEN_BIN_DIR/$TOOL.sh", "Generating ($MODE) tests with: $TOOL")
        or die("Failed to generate tests!");

my $ret_code = 0;
# Did the tool generate any tests?
if(system("find $TMP_DIR/$TOOL -name \"*.java\" | grep -q '.'") == 0) {
    # Compress generated tests and copy archive to output directory
    my $archive = "$PID-$VID-$TOOL.$TID.tar.bz2";
    Utils::exec_cmd("tar -cjf $TMP_DIR/$archive -C $TMP_DIR/$TOOL/ .", "Creating test suite archive")
            or die("Cannot archive and compress test suite!");

    $LOG->log_msg("Created test suite archive: $archive");

    my $dir = "$OUT_DIR/$PID/$TOOL/$TID";
    # Create output directory
        Utils::exec_cmd("mkdir -p $dir", "Creating output directory")
                or die("Failed to create output directory!");
    # Move test suite to OUT_DIR/pid/generator/test_id
    # e.g., .../Lang/randoop/1 or .../Lang/evosuite/1
    Utils::exec_cmd("mv $TMP_DIR/$archive $dir", "Moving test suite archive to $OUT_DIR")
            or die("Cannot move test suite archive to output directory!");

    $LOG->log_msg("Moved test suite archive to output directory: $dir");
} else {
    $LOG->log_msg("Test generator ($TOOL) did not generate any tests!");
    printf(STDERR "Test generator ($TOOL) did not generate any tests!\n");
    # Signal failure to generate any tests
    $ret_code = 127;
}
$LOG->log_time("End test generation");

# Close temporary log and append content to log file in output directory
$LOG->close();
system("cat $LOG->{file_name} >> $LOG_FILE");

# Remove temporary directory
system("rm -rf $TMP_DIR") unless $DEBUG;

# Signal success or failure reason
exit($ret_code);

################################################################################
# Check whether the requested generator is valid
sub is_generator_valid {
    @_ == 1 or die $ARG_ERROR;
    my ($tool) = @_;
    my %all_tools;
    opendir(my $dir, "$TESTGEN_BIN_DIR") || die("Cannot read test generators: $!");
        while (readdir $dir) {
            /^([^_].+)\.sh/ and $all_tools{$1} = 1;
        }
    closedir $dir;
    unless(defined $all_tools{$tool}) {
        print("Supported test generators:\n");
        foreach (sort keys %all_tools) {
            print("- $_\n");
        }
        return 0;
    }
    return 1;
}
################################################################################
