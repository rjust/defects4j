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

create_bugs_table.pl -- populate bugs table with id, name, and number of bugs per project.

=head1 SYNOPSIS

  create_bugs_table.pl

=head1 DESCRIPTION

Determines all active and deprecated bugs ids and outputs a table in Markdown format.

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
opendir(my $dir, "$CORE_DIR/Project") or die "Cannot open directory: $!";
my @files = readdir($dir);
closedir($dir);

# For each project module, instantiate project and determine its name and number
# of active and deprecated bugs.
my $active_total = 0;
my $deprecated_total = 0;
my @projects = ();
for my $file (sort @files) {
    $file =~ "^([^.]+)\.pm\$" or next;
    my $pid=$1;
    my $project = Project::create_project($pid);
    my $name = $project->{prog_name};
    my @active_bug_ids = $project->get_bug_ids();
    my $num_bugs = scalar(@active_bug_ids);

    # Read all bug ids from meta data (trigger tests)
    opendir(my $dir, "$PROJECTS_DIR/$pid/trigger_tests") or die "Cannot open directory: $!";
    my @all_bug_ids = grep(/\d+/, readdir($dir));
    closedir($dir);

    my @deprecated = (scalar(@all_bug_ids)==scalar(@active_bug_ids) ? () : _diff(@all_bug_ids, @active_bug_ids));
    my $num_deprecated_bugs = scalar(@deprecated);

    # Cache id, name, and number of bugs; update total number of bugs
    push(@projects, [$pid, $name, $num_bugs, _range(@active_bug_ids), _range(@deprecated)]);
    $active_total += $num_bugs;
    $deprecated_total += $num_deprecated_bugs;
}

# Print the summary as a markdown table
print("Defects4J contains $active_total bugs (plus $deprecated_total deprecated bugs) from the following open-source projects:\n\n");
print("| Identifier      | Project name               | Number of active bugs | Active bug ids      | Deprecated bug ids (\\*) |\n");
print("|-----------------|----------------------------|----------------------:|---------------------|-------------------------| \n");
for (@projects) {
    printf("| %-15s | %-26s |          %3d          | %-19s | %-23s |\n", $_->[0], $_->[1], $_->[2], $_->[3], $_->[4]);
}

#
# Compute and format bug id ranges
#
sub _range {
  my @ids = @_;
  if(scalar(@ids)==0) {
    return("None");
  }
  my @ranges;
  for (@ids) {
     if (@ranges && $_ == $ranges[-1][1]+1) {
        ++$ranges[-1][1];
     } else {
        push(@ranges, [$_, $_ ]);
     }
  }

  return(join(',', map { $_->[0] == $_->[1] ? $_->[0] : "$_->[0]-$_->[1]" } @ranges));
}

#
# Compute the difference between two arrays
#
sub _diff {
  my (@all, @active) = @_;

  my @diff;
  my @count = ();
  foreach (@all, @active) {
    $count[$_]++;
  }
  for my $i (1..$#count) {
    push(@diff, $i) unless($count[$i] == 2);
  }

  return(@diff);
}
