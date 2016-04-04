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

run_randoop.pl -- generate test suites using Randoop.

=head1 SYNOPSIS

  run_randoop.pl -p project_id -v version_id -n test_id -o out_dir -b budget [-t tmp_dir] [-D]

=head1 OPTIONS

=over 4

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

This script runs Randoop for a particular program version.  Tests are generated for all
classes touched by the triggering tests.

=head2 Randoop configuration

The filename of an optional Randoop configuration file can be provided with the
environment variable C<RANDOOP_CONFIG_FILE>. The default configuration file of Randoop
is: F<framework/util/randoop.config>.

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
# TODO: Integrate test generation in defects4j as a command (e.g., defects4j gen-tests)
# TODO: Build module for test generation, which provides common sub routines for
# logging and compressing the test suites. Maybe extract all config options to
# the configuration files so that the gen-tests has the same cmd options for all
# test generators.
#


#
# Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('p:v:o:n:b:t:D', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and
                    defined $cmd_opts{v} and
                    defined $cmd_opts{n} and
                    defined $cmd_opts{b} and
                    defined $cmd_opts{o};
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

By default, the script logs all errors and warnings to F<run_randoop.log> in
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
my $LOG = Log::create_log("$TMP_DIR/run_randoop.log");

$LOG->log_time("Start test generation");

# Build class list arguments
my $test_classes="--classlist=$LOADED_CLASSES";
my $target_classes="--include-if-class-exercised=$MOD_CLASSES";

# Iterate over all modified classes
my $log = "$TMP_DIR/$PID.$VID.$TID.log";
$LOG->log_msg("Generate tests for: $PID-$VID-$TID");
# Read Randoop configuration
my $config = "$UTIL_DIR/randoop.config";
# Set config to environment variable if defined
$config = $ENV{RANDOOP_CONFIG_FILE} // $config;

# Use test_id and bug_id as random seed -- randoop is by default NOT random!

# TODO: Enable target class filtering once Randoop is fixed.
# $project->run_randoop("$test_classes $target_classes", $TIME, ($TID*1000 + $BID), $config, $log) or die "Failed to generate tests!";
$project->run_randoop("$test_classes", $TIME, ($TID*1000 + $BID), $config, $log) or die "Failed to generate tests!";

# Copy log file for this version id and test criterion to output directory
system("mv $log $LOG_DIR") == 0 or die "Cannot copy log file!";
# Compress generated tests and copy archive to output directory
my $archive = "$PID-$VID-randoop.$TID.tar.bz2";

if (-e "$TMP_DIR/randoop/RegressionTest.java") {
    system("rm $TMP_DIR/randoop/RegressionTest.java");
} else {
    $LOG->log_msg("Error: expected test suite RegressionTest.java does not exist!");
}

if (system("tar -cjf $TMP_DIR/$archive -C $TMP_DIR/randoop/ .") != 0) {
    $LOG->log_msg("Error: cannot archive and compress test suites!");
}

=pod

=head2 Test suites

The source files of the generated test suite are compressed into an archive with the
following name:
F<C<project_id>-C<version_id>-randoop.C<test_id>.tar.bz2>

Examples:

=over 4

=item * F<Lang-12b-randoop.1.tar.bz2>

=item * F<Lang-12f-randoop.2.tar.bz2>

=back

The test suite archive is written to:
F<out_dir/C<project_id>/randoop/C<test_id>>

=cut

# Move test suite to OUT_DIR/pid/suite_src/test_id
#
# e.g., .../Lang/randoop/1
#
my $dir = "$OUT_DIR/$PID/randoop/$TID";
system("mkdir -p $dir && mv $TMP_DIR/$archive $dir") == 0 or die "Cannot copy test suite archive to output directory!";

$LOG->log_time("End test generation");

# Close temporary log and append content to log file in output directory
$LOG->close();
system("cat $LOG->{file_name} >> $LOG_FILE");

# Remove temporary directory
system("rm -rf $TMP_DIR") unless $DEBUG;
