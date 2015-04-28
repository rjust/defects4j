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

sanity_check.pl -- Checks out each revision of the given project and runs
the sanity_check on it. Dies if any case fails.

=head1 SYNOPSIS

sanity_check.pl -p project_id [-v version_id] [-t tmp_dir]

=cut
use warnings;
use strict;

use FindBin;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Project;

#
# Issue usage message and quit
#
sub _usage {
    die "usage: $0 -p project_id [-v version_id] [-t tmp_dir]"
}

my %cmd_opts;
getopts('p:v:t:', \%cmd_opts) or _usage();

_usage() unless defined $cmd_opts{p};

my $PID = $cmd_opts{p};
my $VID = $cmd_opts{v};


# Set up project
my $TMP_DIR = Utils::get_tmp_dir($cmd_opts{t}); 
system("mkdir -p $TMP_DIR");
my $project = Project::create_project($PID);
$project->{prog_root} = $TMP_DIR;
 
my @ids;
if (defined $VID) {
    @ids = ($VID);
} else {
    @ids = $project->get_version_ids();

}

foreach my $id (@ids) {
    printf ("%4d: $project->{prog_name}\n", $id);
    foreach my $v ("b", "f") {
        $project->checkout_id("${id}$v") == 0 or die "Could not checkout ${id}$v";
        $project->sanity_check() == 0 or die "Could not perform sanity check on ${id}$v";
       
        my $rev = $project->lookup("${id}$v"); 
        
        my $src_dir = $project->src_dir($rev);
        -e "$TMP_DIR/$src_dir" or die "Provided source directory does not exist in ${id}$v";
        
        my $test_dir = $project->test_dir($rev);
        -e "$TMP_DIR/$test_dir" or die "Provided test directory does not exist in ${id}$v";
    }
}
# Clean up
system("rm -rf $TMP_DIR");

=pod

=head1 SEE ALSO

All valid project_ids are listed in F<Project.pm>

=cut
