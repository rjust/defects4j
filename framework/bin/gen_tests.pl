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

gen_tests.pl -- generate a test suite using one of the supported tools.

=head1 SYNOPSIS

  gen_tests.pl -g generator -p project_id -v version_id -n test_id -o out_dir -b budget [-t tmp_dir] [-D]

=head1 OPTIONS

=over 4

=item -g C<generator>

The test generator to use. Run the following command to see a list of supported
test generators: C<run_test_gen.pl -g help>

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

=item -b C<budget>

The time in seconds allowed for test generation.

=item -t F<tmp_dir>

The temporary root directory to be used to check out the program version (optional).
The default is F</tmp>.

=item -D

Debug: Enable verbose logging and do not delete the temporary check-out directory
(optional).

=back

=head1 DESCRIPTION

This script runs the specified test generator on a particular program version.
Tests are generated for all classes touched by at least one triggering tests.

=head2 Tool configuration

The following wrapper script invokes the specified test generator and provides
the generator-specific configuration:
F<C<TESTGEN_LIB_DIR>/bin/_C<GENERATOR>.sh>.

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
getopts('g:p:v:o:n:b:t:D', \%cmd_opts) or pod2usage(1);
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

my $TID = $cmd_opts{n};
$TID =~ /^\d+$/ or die "Wrong test_id format (\\d+): $TID!";
my $TIME = $cmd_opts{b};
$TIME =~ /^\d+$/ or die "Wrong budget format (\\d+): $TIME!";
my $OUT_DIR = $cmd_opts{o};

# Enable debugging if flag is set
$DEBUG = 1 if defined $cmd_opts{D};

# List of loaded classes
my $LOADED_CLASSES = "$SCRIPT_DIR/projects/$PID/loaded_classes/$BID.src";

# List of modified classes
my $MOD_CLASSES = "$SCRIPT_DIR/projects/$PID/modified_classes/$BID.src";

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
$LOG->log_time("Start test generation: $PID-$VID-$TID");
$LOG->log_msg("Parameters:");
$LOG->log_msg(" -g $TOOL");
$LOG->log_msg(" -n $TID");
$LOG->log_msg(" -b $TIME");

my $cp_file = "$TMP_DIR/project.cp";                               
$project->_ant_call("export.cp.compile", "-Dfile.export=$cp_file")
        or die "Cannot determine project classpath";

# Export all environment variables that are expected by the wrapper script of
# the test generator.
$ENV{D4J_HOME}                = "$BASE_DIR";
$ENV{D4J_FILE_ALL_CLASSES}    = "$LOADED_CLASSES";
$ENV{D4J_FILE_TARGET_CLASSES} = "$MOD_CLASSES";
$ENV{D4J_DIR_WORKDIR}         = "$TMP_DIR";
$ENV{D4J_DIR_OUTPUT}          = "$TMP_DIR/$TOOL";
$ENV{D4J_DIR_LOG}             = "$LOG_DIR";
$ENV{D4J_DIR_TESTGEN_LIB}     = "$TESTGEN_LIB_DIR";
$ENV{D4J_CLASS_BUDGET}        = "$TIME";
# Use test_id and bug_id to compute the random seed!
$ENV{D4J_SEED}                = ($TID*1000 + $BID);

# Invoke the test generator
Utils::exec_cmd("$TESTGEN_LIB_DIR/bin/$TOOL.sh", "Generating tests ($TOOL)") or die "Failed to generate tests!";
# Print reference to the tool paper
system("cat $TESTGEN_LIB_DIR/bin/$TOOL.credit");

# Compress generated tests and copy archive to output directory
my $archive = "$PID-$VID-$TOOL.$TID.tar.bz2";

if (system("tar -cjf $TMP_DIR/$archive -C $TMP_DIR/$TOOL/ .") != 0) {
    $LOG->log_msg("Error: cannot archive and compress test suites!");
} else {
    $LOG->log_msg("Created test suite archive: $archive");
}

=pod

=head2 Test suites

The source files of the generated test suite are compressed into an archive with
the following name:
F<C<project_id>-C<version_id>-C<tool>.C<test_id>.tar.bz2>

Examples:

=over 4

=item * F<Lang-12b-randoop.1.tar.bz2>

=item * F<Lang-12f-randoop.2.tar.bz2>

=item * F<Lang-12f-evosuite.1.tar.bz2>

=item * F<Lang-12f-t3.1.tar.bz2>

=back

The test suite archive is written to:
F<out_dir/C<project_id>/C<TOOL>/C<test_id>>

=cut

# Move test suite to OUT_DIR/pid/suite_src/test_id
#
# e.g., .../Lang/randoop/1
#       .../Lang/evosuite/1
#       .../Lang/t3/1
#
my $dir = "$OUT_DIR/$PID/$TOOL/$TID";
system("mkdir -p $dir && mv $TMP_DIR/$archive $dir") == 0
        or die "Cannot move test suite archive to output directory!";
    
$LOG->log_msg("Moved test suite archive to output directory: $dir");

$LOG->log_time("End test generation");

# Close temporary log and append content to log file in output directory
$LOG->close();
system("cat $LOG->{file_name} >> $LOG_FILE");

# Remove temporary directory
system("rm -rf $TMP_DIR") unless $DEBUG;

################################################################################
# Check whether the requested generator is valid
sub is_generator_valid {
    my $tool = shift;
    my %all_tools;
    opendir(my $dir, "$TESTGEN_LIB_DIR/bin") || die("Cannot read test generators: $!");
        while (readdir $dir) {
            /^(.*)\.sh/ and $all_tools{$1} = 1;
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
