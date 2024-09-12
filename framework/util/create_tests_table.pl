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

create_tests_tablepl -- populate test-stats table with project id and number of broken/flaky tests.

=head1 SYNOPSIS

  create_tests_table.pl

=head1 DESCRIPTION

Determines all broken/flaky tests per project and outputs a table in Markdown format.

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

# Read all project modules
opendir(my $dh, "$CORE_DIR/Project") or die "Cannot open directory: $!";
my @files = readdir($dh);
closedir($dh);

# Instantiate each project and determine all broken/flaky tests across all bugs.
my @projects = ();
for my $file (sort @files) {
    $file =~ "^([^.]+)\.pm\$" or next;
    my $pid=$1;
    my $project = Project::create_project($pid);
    my $name = $project->{prog_name};
    my @active_bug_ids = $project->get_bug_ids();
    my $num_bugs = scalar(@active_bug_ids);

    # Read all failing_tests (broken tests)
    my %all_classes;
    my %all_methods;
    if (-d _dir_fail($pid)) {
        opendir(my $dh, _dir_fail($pid)) or die "Cannot open directory ($pid): $!";
        while (my $file = readdir($dh)) {
            my $tests = Utils::get_failing_tests(_dir_fail($pid) . "/$file");
            foreach my $class (@{$tests->{classes}}) {
                $all_classes{$class} += 1;
            }
            foreach my $method (@{$tests->{methods}}) {
                $all_methods{$method} += 1;
            }
        }
        closedir($dh);
    }
    my $fail_classes = scalar(keys(%all_classes));
    my $fail_methods = scalar(keys(%all_methods));

    # Read all random-tests and dependent-tests (flaky tests) 
    my $flaky_classes = 0;
    my $flaky_methods = 0;
    foreach my $file ((_file_rnd($pid), _file_dep($pid))) {
        next if (! -e $file);
        my $tests = Utils::get_failing_tests($file);
        my %uniq = map { $_ => 1 } @{$tests->{classes}};
        $flaky_classes += scalar(keys(%uniq));
        %uniq = map { $_ => 1 } @{$tests->{methods}};
        $flaky_methods += scalar(keys(%uniq));
    }

    # Cache id, name, and number of tests
    push(@projects, [$pid, $name, $fail_classes, $fail_methods, $flaky_classes, $flaky_methods]);
}

# Print the summary as a markdown table
print("Defects4J excludes broken and flaky tests:\n\n");
print("| Identifier      | Project name               | Broken classes | Broken methods | Flaky classes | Flaky methods |\n");
print("|-----------------|----------------------------|---------------:|---------------:|--------------:|--------------:| \n");
for (@projects) {
    printf("| %-15s | %-26s |            %3d |            %3d |           %3d |           %3d |\n",
        $_->[0], $_->[1], $_->[2], $_->[3], $_->[4], $_->[5]);
}

sub _dir_fail { my $pid = shift; return("$PROJECTS_DIR/$pid/failing_tests") };
sub _file_rnd { my $pid = shift; return("$PROJECTS_DIR/$pid/random_tests") };
sub _file_dep { my $pid = shift; return("$PROJECTS_DIR/$pid/dependent_tests") };
