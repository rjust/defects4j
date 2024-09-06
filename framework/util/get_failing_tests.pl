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
# THE SOFTWARE IS PROBIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

=pod

=head1 NAME

get_failing_tests.pl -- determine the set of failing tests for the fixed project versions of a given project.

=head1 SYNOPSIS

  get_failing_tests.pl -p project_id [-b bug_id] [-t tmp_dir] [-o out_dir]

=head1 OPTIONS

=over 4

=item -p C<project_id>

The id of the project for which the failing tests are determined.

=item -b C<bug_id>

Only determine failing tests for this bug id (optional). Format: C<\d+>

=item B<-t F<tmp_dir>>

The temporary root directory to be used to check out revisions (optional).
The default is F</tmp>.

=item B<-o F<out_dir>>

The output directory to be used (optional).
The default is F<FILE_FAILING_TESTS> in Defects4J's project directory.

=back

=head1 DESCRIPTION

Determines the set of failing tests for each bug (or a particular bug) of a
given project. The script stops as soon as an error occurs for any project version.

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
getopts('p:b:t:o:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p};

my $PID = $cmd_opts{p};
my $BID = $cmd_opts{b};


# Set up project
my $TMP_DIR = Utils::get_tmp_dir($cmd_opts{t});
system("mkdir -p $TMP_DIR");
my $project = Project::create_project($PID);
$project->{prog_root} = $TMP_DIR;
my $project_dir = "$PROJECTS_DIR/$PID";
my $out_dir = $cmd_opts{o} // "$project_dir/$FILE_FAILING_TESTS";

my @ids;
if (defined $BID) {
    $BID =~ /^(\d+)$/ or die "Wrong bug_id format: $BID! Expected: \\d+";
    @ids = ($BID);
} else {
    @ids = $project->get_bug_ids();
}

foreach my $bid (@ids) {
    printf ("%4d: $project->{prog_name}\n", $bid);
    my $vid = "${bid}f";
    my $rev_id = $project->lookup($vid);
    my $out_file = "$PROJECTS_DIR/$PID/failing_tests/$rev_id";

    if (-e $out_file) {
      # Remove existing file, which would otherwise result in some tests being
      # excluded during checkout.
      Utils::exec_cmd("mv $out_file $out_file.bak", "Remove failing-tests file") or die "Cannot remove existing file";
    }
    $project->checkout_vid($vid) or die "Could not checkout ${vid}";
    $project->compile() or die "Could not compile";
    $project->compile_tests() or die "Could not compile tests";
    my $tmp_file = "$project->{prog_root}/failing_tests";
    $project->run_tests($tmp_file) or die "Could not run tests";

    Utils::has_failing_tests($tmp_file) or next;


    open(OUT, ">$out_file") or die "Cannot write failing tests: $!";
    print(OUT "## $project->{prog_name}: $vid ($rev_id) ##\n");
    close(OUT);
    system("cat $tmp_file >> $out_file");
}
# Clean up
system("rm -rf $TMP_DIR");
