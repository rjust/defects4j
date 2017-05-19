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

sanity_check.pl -- perform sanity check for a project or project version.

=head1 SYNOPSIS

  sanity_check.pl -p project_id [-b bug_id] [-t tmp_dir]

=head1 DESCRIPTION

Checks out each project version, and runs the sanity check on it. Dies if any run fails.

=head1 OPTIONS

=over 4

=item -p C<project_id>

The id of the project for which the sanity check is run.
See L<Project|Project/"Available Project IDs"> module for available project IDs.

=item -b C<bug_id>

Only run the sanity check for this bug id (optional). Format: C<\d+>.

=item -t F<tmp_dir>

The temporary root directory to be used to check out revisions (optional).
The default is F</tmp>.

=back

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
use Project;

#
# Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('p:b:t:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p};

my $PID = $cmd_opts{p};
my $BID = $cmd_opts{b};

# Set up project
my $TMP_DIR = Utils::get_tmp_dir($cmd_opts{t});
system("mkdir -p $TMP_DIR");
my $project = Project::create_project($PID);
$project->{prog_root} = $TMP_DIR;

my @ids;
if (defined $BID) {
    $BID =~ /^(\d+)$/ or die "Wrong bug_id format: $BID! Expected: \\d+";
    @ids = ($BID);
} else {
    @ids = $project->get_version_ids();
}

foreach my $bid (@ids) {
    printf ("%4d: $project->{prog_name}\n", $bid);
    foreach my $v ("b", "f") {
        my $vid = "${bid}$v";
        $project->checkout_vid($vid) or die "Could not checkout ${vid}";
        $project->sanity_check() or die "Could not perform sanity check on ${vid}";

        # Check whether source directory is properly exported
        my $src_dir = $project->src_dir($vid);
        my $exp_src_dir = `cd $TMP_DIR && $SCRIPT_DIR/bin/defects4j export -pdir.src.classes`; chomp $exp_src_dir;
        -e "$TMP_DIR/$src_dir" or die "Provided source directory does not exist in ${vid}";
        $exp_src_dir eq $src_dir or die "Exported source directory does not match expected one ($exp_src_dir != $src_dir) in ${vid}";

        # Check whether test directory is properly exported
        my $test_dir = $project->test_dir($vid);
        my $exp_test_dir = `cd $TMP_DIR && $SCRIPT_DIR/bin/defects4j export -pdir.src.tests`; chomp $exp_test_dir;
        -e "$TMP_DIR/$test_dir" or die "Provided test directory does not exist in ${vid}";
        $exp_test_dir eq $test_dir or die "Exported test directory does not match expected one ($exp_test_dir != $test_dir) in ${vid}";

        # Verify the following properties:
        # - All tests pass on the fixed version
        # - Only expected triggering test(s) fail on the buggy version
        # - All expected triggering test(s) fail on the buggy version
        $project->compile() or die "Could not compile sources: ${vid}";
        $project->compile_tests() or die "Could not compile tests: ${vid}";

        my $failing_tests = "$TMP_DIR/.failing_tests";
        system(">$failing_tests");
        $project->run_relevant_tests($failing_tests) or die "Could not run relevant tests: ${vid}";
        my $trigger = Utils::get_failing_tests($failing_tests) or die "Cannot determine triggering tests!";
        my $count = scalar(@{$trigger->{methods}}) + scalar(@{$trigger->{classes}});
        my %actual_triggers = ();
        if ($count != 0) {
            print("Failing tests:\n");
            foreach my $test ((@{$trigger->{classes}}, @{$trigger->{methods}})) {
                $actual_triggers{$test} = 1;
                print("  - $test\n");
            }
        }

        # Check fixed version
        if ("f" eq $v) {
            $count == 0 or die "Unexptected failing tests on fixed version: $vid";
        }
        # Check buggy version
        else {
            my $error = 0;
            # Get all expected triggering tests
            $trigger = Utils::get_failing_tests("$SCRIPT_DIR/projects/$PID/trigger_tests/$bid") or die "Cannot determine expected triggering tests!";
            # Verify that each expected triggering test indeed exists in actual triggers
            foreach my $test ((@{$trigger->{classes}}, @{$trigger->{methods}})) {
                if (!defined $actual_triggers{$test}) {
                    print("Exptected triggering test is missing: $test");
                    $error = 1;
                }
                delete $actual_triggers{$test};
            }
            # Verify that only expected triggering tests existed in actual triggers
            if (! scalar(%actual_triggers) == 0) {
                print("Unexpected triggering tests:\n");
                foreach my $test (keys(%actual_triggers)) {
                    print("  - $test\n");
                }
                $error = 1;
            }

            $error == 0 or die "Set of triggering tests is unexpected: $vid";
        }
    }
}
# Clean up
system("rm -rf $TMP_DIR");
