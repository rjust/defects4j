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
                           layout and perform a sanity check for each revision.

=head1 SYNOPSIS

initialize-revisions.pl -p project_id -w work_dir [ -b bug_id]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the project for which the revisions are initialized.

=item B<-w C<work_dir>>

Use C<work_dir> as the working directory.

=item B<-b C<bug_id>>

Only analyze this bug id or interval of bug ids (optional).
The bug_id has to have the format B<(\d+)(:(\d+))?> -- if an interval is
provided, the interval boundaries are included in the analysis.
Per default all bug ids listed in the commit-db are considered.

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
getopts('p:b:w:', \%cmd_opts) or pod2usage(1);

my ($PID, $BID, $WORK_DIR) =
    ($cmd_opts{p},
     $cmd_opts{b},
     $cmd_opts{w}
    );

pod2usage(1) unless defined $PID and defined $WORK_DIR; # $BID can be undefined

# Check format of target version id
if (defined $BID) {
    $BID =~ /^(\d+)(:(\d+))?$/ or die "Wrong version id format ((\\d+)(:(\\d+))?): $BID!";
}

# if work dir is relative make it absolute, this will prevent problems as the current directory suddenly changes
$WORK_DIR = abs_path($WORK_DIR);

# Add script and core directory to @INC
unshift(@INC, "$WORK_DIR/framework/core");

# Set the projects and repository directories to the current working directory.
$PROJECTS_DIR = "$WORK_DIR/framework/projects";
$REPO_DIR = "$WORK_DIR/project_repos";

# Create necessary directories
my $project_dir = "$WORK_DIR/framework/projects/$PID";

my $PATCH_DIR   = "$project_dir/patches";
my $FAILING_DIR = "$project_dir/failing_tests";
my $TRIGGER_DIR = "$project_dir/trigger_tests";
my $MOD_CLASSES = "$project_dir/modified_classes";

system("mkdir -p $PATCH_DIR $FAILING_DIR $TRIGGER_DIR $MOD_CLASSES");

############################### VARIABLE SETUP
my $TMP_DIR = Utils::get_tmp_dir(); # Temporary directory
system("mkdir -p $TMP_DIR");
# Set up project
my $project = Project::create_project($PID);
$project->{prog_root} = $TMP_DIR;

#
# The Defects4J core framework requires certain metadata for each defect.
# This routine creates these artifacts, if necessary.
#
sub _bootstrap {
    my ($project, $bid) = @_;

    # This defect is already initialized
    -e "$PATCH_DIR/$bid.src.patch" and return;

    my $v1 = $project->lookup("${bid}b");
    my $v2 = $project->lookup("${bid}f");

    # Use the VCS checkout routine, which does not apply the cached, possibly
    # minimized patch to obtain the buggy version.
    $project->{_vcs}->checkout_vid("${bid}b", $TMP_DIR) or die "Cannot checkout pre-fix version";
    $project->initialize_revision($v1, "${bid}b");
    my ($src_b, $test_b) = ($project->src_dir("${bid}b"), $project->test_dir("${bid}b"));

    $project->{_vcs}->checkout_vid("${bid}f", $TMP_DIR) or die "Cannot checkout post-fix version";
    $project->initialize_revision($v2, "${bid}f");
    my ($src_f, $test_f) = ($project->src_dir("${bid}f"), $project->test_dir("${bid}f"));

    die "Source directories don't match for buggy and fixed revisions of $bid" unless $src_b eq $src_f;
    die "Test directories don't match for buggy and fixed revisions of $bid" unless $test_b eq $test_f;

    # Create local patch so that we can use the D4J core framework.
    # Minimization doesn't matter here, which has to be done manually.
    $project->export_diff($v2, $v1,"$PATCH_DIR/$bid.src.patch", "$src_f");
    $project->export_diff($v2, $v1,"$PATCH_DIR/$bid.test.patch", "$test_f");
}

################################################################################
# figure out which IDs to run script for
my @ids = $project->get_version_ids();
if (defined $BID) {
    if ($BID =~ /(\d+):(\d+)/) {
        @ids = grep { ($1 <= $_) && ($_ <= $2) } @ids;
    } else {
        # single bid
        @ids = grep { ($BID == $_) } @ids;
    }
}

foreach my $bid (@ids) {
    printf ("%4d: $project->{prog_name}\n", $bid);

    # Populate the layout map and patches directory
    _bootstrap($project, $bid);

    # Defects4J cannot handle empty patch files -> skip the sanity check since
    # these candidates are filtered in a later step anyway.
    if (-z "$PATCH_DIR/$bid.src.patch") {
        printf ("Empty source patch -> skip candidate\n");
        next;
    }

    # Clean the temporary directory
    Utils::exec_cmd("rm -rf $TMP_DIR && mkdir -p $TMP_DIR", "Cleaning working directory")
            or die "Cannot clean working directory";
    $project->checkout_vid("${bid}f", $TMP_DIR, 1) or die "Cannot checkout fixed version";
    $project->sanity_check();
}

system("rm -rf $TMP_DIR");
