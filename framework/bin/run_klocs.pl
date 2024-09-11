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

run_klocs.pl -- count test suite KLOCS.

=head1 SYNOPSIS

  run_klocs.pl -p project_id -v version_id -n test_id -o out_dir [-D]

=head1 OPTIONS

=over 4

=item -p C<project_id>

Count KLOCs for this project id.
See L<Project|Project/"Available Project IDs"> module for available project IDs.

=item -v C<version_id>

Count KLOCs for this version id.
Format: C<\d+[bf]>.

=item -n C<test_id>

The id of the generated test suite (i.e., which run of the same configuration).

=item -o F<out_dir>

The root output directory for the generated test suite. The test suite and logs are
written to:
F<out_dir/project_id/version_id>.

=item -D

Debug: Enable verbose logging and do not delete the temporary check-out directory
(optional).

=back

=head1 DESCRIPTION

This script prepares a particular program version as if it was going to run Randoop on it.
It then counts the program KLOCS to use later in calculating Randoop test coverage.

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
getopts('p:v:o:n:D', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and
                    defined $cmd_opts{v} and
                    defined $cmd_opts{n} and
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
my $OUT_DIR = $cmd_opts{o};

# Enable debugging if flag is set
$DEBUG = 1 if defined $cmd_opts{D};

if ($DEBUG) {
  Utils::print_env();
}

# List of loaded classes
my $LOADED_CLASSES = "$SCRIPT_DIR/projects/$PID/loaded_classes/$BID.src";

# Temporary directory for project checkout
my $TMP_DIR = Utils::get_tmp_dir();
system("mkdir -p $TMP_DIR");

# Set working directory
$project->{prog_root} = $TMP_DIR;

# Checkout project
$project->checkout_vid($VID) or die "Cannot checkout!";

my $output;
#my $output = `env`;
#print "env\n$output\n";
#my $x=$ENV{'PWD'};
#print "PWD: ", $x, "\n";

my $extcode;
# run count-klocs.pl on the generated sources
if (defined $cmd_opts{D}) {
    $output = `$SCRIPT_DIR/test/count_klocs.pl -d $TMP_DIR $PID $BID`;
    $extcode = $?>>8;
} else {
    $output = `$SCRIPT_DIR/test/count_klocs.pl $TMP_DIR $PID $BID`;
    $extcode = $?>>8;
}
print "count klocs output:\n$output\n";

# Remove temporary directory
system("rm -rf $TMP_DIR") unless defined $cmd_opts{D};
exit $extcode;
