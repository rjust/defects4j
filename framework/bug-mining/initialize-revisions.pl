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

initialize-revisions.pl -- Initialize all revisions: identify the directory 
                           layout and perform a sanity check on each revision.

=head1 SYNOPSIS

initialize-revisions.pl -p project_id -w work_dir [ -v version_id]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the project for which the revisions are initialized.

=item B<-w C<work_dir>>

Use C<work_dir> as the working directory.

=item B<-v C<version_id>>

Only analyze this version id or interval of version ids (optional).
The version_id has to have the format B<(\d+)(:(\d+))?> -- if an interval is
provided, the interval boundaries are included in the analysis.
Per default all version ids are considered.

=back

=cut

use warnings;
use strict;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;
use Project;
use DB;
use Utils;

############################## ARGUMENT PARSING
my %cmd_opts;
getopts('p:v:w:', \%cmd_opts) or pod2usage(1);

my ($PID, $VID, $WORK_DIR) =
    ($cmd_opts{p},
     $cmd_opts{v},
     $cmd_opts{w}
    );

pod2usage(1) unless defined $PID and defined $WORK_DIR; # $VID can be undefined

# Check format of target version id
if (defined $VID) {
    $VID =~ /^(\d+)(:(\d+))?$/ or die "Wrong version id format ((\\d+)(:(\\d+))?): $VID!";
}

############################### VARIABLE SETUP
# Temporary directory
my $TMP_DIR = Utils::get_tmp_dir();
system("mkdir -p $TMP_DIR");
# Set up project
my $project = Project::create_project($PID, $WORK_DIR);
$project->{prog_root} = $TMP_DIR;

############################### MAIN LOOP
# figure out which IDs to run script for
my @ids = $project->get_version_ids();
if (defined $VID) {
    if ($VID =~ /(\d+):(\d+)/) {
        @ids = grep { ($1 <= $_) && ($_ <= $2) } @ids;
    } else {
        # single vid
        @ids = grep { ($VID == $_) } @ids;
    }
}

foreach my $vid (@ids) {
    printf ("%4d: $project->{prog_name}\n", $vid);

    my $v1 = $project->lookup("${vid}b");
    my $v2 = $project->lookup("${vid}f");

    $project->checkout_id("${vid}b");
    $project->sanity_check();
    $project->initialize_revision($v1, "${vid}b");
    my ($src_b, $test_b) = ($project->src_dir($v1), $project->test_dir($v1));

    $project->checkout_id("${vid}f");
    $project->sanity_check();
    $project->initialize_revision($v2, "${vid}f");
    my ($src_f, $test_f) = ($project->src_dir($v2), $project->test_dir($v2));

    die "Source directories don't match for buggy and fixed revisions of $vid" unless $src_b eq $src_f;
    die "Test directories don't match for buggy and fixed revisions of $vid" unless $test_b eq $test_f;
}
system("rm -rf $TMP_DIR");

