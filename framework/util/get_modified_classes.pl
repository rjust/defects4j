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

get_modified_classes.pl -- Determine the set of classes modified by the patch of a given
defect.

=head1 SYNOPSIS

  get_modified_classes.pl -p project_id -b bug_id [-o output_file]

=head1 OPTIONS

=over 4

=item -p C<project_id>

The id of the project for which the patch should be analyzed.

=item -b C<bug_id>

The id of the bug for which the patch should be analyzed.

=item -o F<output_file>

Write output to this file (optional). By default the script prints the modified classes to
stdout. Note that all diagnostic messages are sent to stderr.

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
getopts('p:b:o:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{b};
my $PID      = $cmd_opts{p};
my $BID      = $cmd_opts{b};
my $OUT_FILE = $cmd_opts{o};

# Set up project and determine the source directory
my $project = Project::create_project($PID);
my $src_dir = $project->src_dir("${BID}f");

# Directory that holds all patches for the given project ID
my $patch = "$SCRIPT_DIR/projects/$PID/patches/$BID.src.patch";
-e $patch or die "Cannot read patch: $patch";

my $classes;

# Run diffstat to determine the modified files
Utils::exec_cmd("diffstat -l -p1 $patch", "Analyzing patch", \$classes);

# Translate Java file name into class name
$classes =~ s/$src_dir\/?//g;
$classes =~ s/\.java//g;
$classes =~ s/\//\./g;

if (defined $OUT_FILE) {
    open(OUT, ">$OUT_FILE") or die "Cannot write output file";
        print(OUT $classes);
    close(OUT);
} else {
    print($classes);
}
