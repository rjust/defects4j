#!/usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2020 René Just, Darioush Jalali, and Defects4J contributors.
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

create_bugs_table.pl -- populate bugs table with id, name, and number of bugs per project.

=head1 SYNOPSIS

  create_bugs_table.pl

=head1 DESCRIPTION

Finds all commit-db files and outputs a table for all bugs.

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

# Read all project modules
opendir(my $dir, "$CORE_DIR/Project") or die "Cannot open directory: $!";
my @files = readdir($dir);
closedir($dir);

# For each project module, instantiate project and determine its name and number
# of bugs.
my $total = 0;
my @projects = ();
for my $file (@files) {
    $file =~ "^([^.]+)\.pm\$" or next;
    my $pid=$1;
    my $project = Project::create_project($pid);
    my $name = $project->{prog_name};
    my @bug_ids = $project->get_bug_ids();
    my $num_bugs = scalar(@bug_ids);
    # Cache id, name, and number of bugs; update total number of bugs
    push(@projects, [$pid, $name, $num_bugs]);
    $total += $num_bugs;
}

# Print the summary as a markdown table
print("Defects4J contains $total bugs from the following open-source projects:\n\n");
print("| Identifier      | Project name               | Number of bugs |\n");
print("|-----------------|----------------------------|----------------|\n");
for (@projects) {
    printf("| %-15s | %-26s |      %3d       |\n", $_->[0], $_->[1], $_->[2]);
}
