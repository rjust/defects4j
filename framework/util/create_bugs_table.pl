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
for my $file (sort @files) {
    $file =~ "^([^.]+)\.pm\$" or next;
    my $pid=$1;
    my $project = Project::create_project($pid);
    my $name = $project->{prog_name};
    my @bug_ids = $project->get_bug_ids();
    my $num_bugs = scalar(@bug_ids);
    my $in_use = "";
    my $deprecated = "";

    my $prev_bug = 0;
    my $in_use_low = 1;
    my $in_use_high = 1;
    my $deprecated_low = 1;
    my $deprecated_high = 1;

    for my $bug (@bug_ids) {
        if ($bug != $prev_bug + 1) {
            if ($in_use_low eq $in_use_high) {
                $in_use .= $in_use_low.",";
            } else {
                $in_use .= $in_use_low."-".$in_use_high.",";
            }
            $in_use_low = $bug;

            $deprecated_low = $prev_bug + 1;
            $deprecated_high = $bug - 1;

            if ($deprecated_low eq $deprecated_high) {
                $deprecated .= $deprecated_low.","; 
            } else{ 
                $deprecated .= $deprecated_low."-".$deprecated_high.",";
            }
            $prev_bug = $bug - 1;
        }
        $prev_bug +=1;
        $in_use_high = $bug;
    }

    if ($deprecated eq "") {
        $deprecated = "None,";
    }
    $deprecated = substr($deprecated, 0, -1);

    if ($in_use_low eq $in_use_high) {
        $in_use .= $in_use_low;
    } else {
        $in_use .= $in_use_low."-".$in_use_high;
    }

    # Cache id, name, and number of bugs; update total number of bugs
    push(@projects, [$pid, $name, $num_bugs, $in_use, $deprecated]);
    $total += $num_bugs;
}

# Print the summary as a markdown table
print("Defects4J contains $total bugs from the following open-source projects:\n\n");
print("| Identifier      | Project name               | Number of Bugs | Bug IDs in Use      | Deprecated Bug IDs (\\*) | \n");
print("|-----------------|----------------------------|---------------:|---------------------|-------------------------| \n");
for (@projects) {
    printf("| %-15s | %-26s |      %3d       | %-19s | %-23s |\n", $_->[0], $_->[1], $_->[2], $_->[3], $_->[4]);
}
