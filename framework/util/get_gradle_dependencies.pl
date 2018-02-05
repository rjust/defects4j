#!/usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2018 René Just, Darioush Jalali, and Defects4J contributors.
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

get_gradle_dependencies.pl -- obtain a list of all gradle versions used in the
entire history of a particular project.

=head1 SYNOPSIS

  get_gradle_dependencies.pl -p project_id

=head1 DESCRIPTION

Extract all references to gradle distributions from the project's version
control history.

B<TODO: This script currently expects the repository to be a git repository!>

=head1 OPTIONS

=over 4

=item -p C<project_id>

The id of the project for which the list of gradle dependencies is extracted.

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
getopts('p:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p};

my $PID = $cmd_opts{p};

# Set up project
my $project = Project::create_project($PID);
my $repo = $project->{_vcs}->{repo};
my $cmd = "git -C $repo log -p -- gradle/wrapper/gradle-wrapper.properties | grep distributionUrl";

# Parse the vcs history and grep for distribution urls
my $log;
Utils::exec_cmd($cmd, "Obtaining all gradle dependencies", \$log);

# Process the list and remove duplicates
my %all_deps;
foreach (split(/\n/, $log)) {
    /[+-]distributionUrl=(.+)/ or die "Unexpected line extracted: $_!";
    my $url = $1;
    $url =~ s/\\:/:/g;
    $all_deps{$url} = 1;   
}

# Print the ordered list of dependencies to STDOUT
print(join("\n", sort(keys(%all_deps))), "\n");
