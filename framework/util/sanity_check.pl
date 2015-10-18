#!/usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2015 René Just, Darioush Jalali, and Defects4J contributors.
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

sanity_check.pl -- sanity check of project version.

=head1 SYNOPSIS

sanity_check.pl -p project_id [-v version_id] [-t tmp_dir]

=head1 DESCRIPTION

Checks out each project version runs the sanity check on it. Dies if any run fails.

=head1 OPTIONS

=over 4

=item -p C<project_id>

The id of the project for which the sanity check is performed.
See L<Project> module for available project IDs.

=item -v C<version_id>

Only run sanity check for this version id (optional). Per default all
suitable version ids are considered.

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
getopts('p:v:t:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p};

my $PID = $cmd_opts{p};
my $VID = $cmd_opts{v};


# Set up project
my $TMP_DIR = Utils::get_tmp_dir($cmd_opts{t});
system("mkdir -p $TMP_DIR");
my $project = Project::create_project($PID);
$project->{prog_root} = $TMP_DIR;

my @ids;
if (defined $VID) {
    $VID =~ /^(\d+)$/ or die "Wrong version_id format: $VID! Expected: \\d+";
    @ids = ($VID);
} else {
    @ids = $project->get_version_ids();

}

foreach my $id (@ids) {
    printf ("%4d: $project->{prog_name}\n", $id);
    foreach my $v ("b", "f") {
        my $vid = "${id}$v";
        $project->checkout_vid($vid) or die "Could not checkout ${vid}";
        $project->sanity_check() or die "Could not perform sanity check on ${vid}";

        my $src_dir = $project->src_dir($vid);
        my $exp_src_dir = `cd $TMP_DIR && $SCRIPT_DIR/bin/defects4j export -pdir.src.classes`; chomp $exp_src_dir;
        -e "$TMP_DIR/$src_dir" or die "Provided source directory does not exist in ${vid}";
        $exp_src_dir eq $src_dir or die "Exported source directory does not match expected one ($exp_src_dir != $src_dir) in ${vid}";

        my $test_dir = $project->test_dir($vid);
        my $exp_test_dir = `cd $TMP_DIR && $SCRIPT_DIR/bin/defects4j export -pdir.src.tests`; chomp $exp_test_dir;
        -e "$TMP_DIR/$test_dir" or die "Provided test directory does not exist in ${vid}";
        $exp_test_dir eq $test_dir or die "Exported test directory does not match expected one ($exp_test_dir != $test_dir) in ${vid}";
    }
}
# Clean up
system("rm -rf $TMP_DIR");
