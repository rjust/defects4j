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
    my $in_use = "";
    my $deprecated = "None,";

    my $prev_bug = 0;
    for my $bug (@bug_ids) {
        if ($bug != $prev_bug +1) {
            if ($deprecated eq "None,") {
                $deprecated = $bug;
            } else {
                $deprecated .= $bug;
            }
            $deprecated .= ",";
            $prev_bug = $bug;
        } else {
            $prev_bug +=1;
        }
    }

    $deprecated = substr($deprecated, 0, -1);

    # Cache id, name, and number of bugs; update total number of bugs
    push(@projects, [$pid, $name, $num_bugs, $in_use, $deprecated]);
    $total += $num_bugs;
}

#| Identifier | Project name         | Number of Bugs | Bug IDs in Use      | Deprecated Bug IDs (\*) |
#|------------|----------------------|----------------|---------------------|------------------------|
#| Chart      | JFreeChart           |  26            | 1-26                | None                   |
#| Closure    | Closure compiler     | 174            | 1-62, 64-92, 93-176 | 63, 93                 |
#| Lang       | Apache commons-lang  |  64            | 1, 3-65             | 2                      |
#| Math       | Apache commons-math  | 106            | 1-106               | None                   |
#| Mockito    | Mockito              |  38            | 1-38                | None                   |
#| Time       | Joda-Time            |  26            | 1-21, 23-27         | 22                     |


# Print the summary as a markdown table
print("Defects4J contains $total bugs from the following open-source projects:\n\n");
print("| Identifier      | Project name               | Number of Bugs | Bug IDs in Use      | Deprecated Bug IDs (\*) | \n");
print("|-----------------|----------------------------|----------------|---------------------|------------------------| \n");
for (@projects) {
    printf("| %-15s | %-26s |      %3d       | %-19s | %-21s |\n", $_->[0], $_->[1], $_->[2], $_->[3], $_->[4]);
}
