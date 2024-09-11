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

initialize-project-and-collect-issues.pl -- Configure a new project for
Defects4J, collect all issues from the project issue tracker, and
cross-reference the commit log with the issue numbers known to be bugs.

=head1 SYNOPSIS

initialize-project-and-collect-issues.pl -p project_id -n project_name -w work_dir -r repository_url -g tracker_name -t tracker_project_id -e bug_matching_perl_regexp [-z organization_id] [-q query] [-u tracker_uri] [-l fetching_limit] [-v vcs_type]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the new project (e.g., Lang).

=item B<-n C<project_name>>

The (descriptive) name of the new project (e.g., commons-lang).

=item B<-w C<work_dir>>

The working directory for the bug-mining process.

=item B<-r C<repository_url>>

The remote URL of the source code repository for the new project.
TODO: Currently, this has to be a git repository.

=item B<-g C<tracker_name>>

The source control tracker name, e.g., jira, github, google, or sourceforge.

=item B<-t C<tracker_project_id>>

The name used on the issue tracker to identify the project. Note that this might
not be the same as the Defects4j project name / id, for instance, for the
commons-lang project is LANG.

=item B<-z C<organization_id>>

The organization id required for the github issue tracker, it specifies the
organization the repo is under, e.g., apache.

=item B<-q C<query>>

The query (i.e., filter for bug type or label) sent to the issue tracker.
Suitable defaults for supported trackers are chosen so they identify only bugs.

=item B<-u C<tracker-uri>>

The URI used to locate the issue tracker. Suitable defaults have been chosen for
supported trackers, but you may change it, e.g., point it to a corporate GitHub
URI.

=item B<-l C<fetching_limit>>

The maximum number of issues to fetch at a time. Most issue trackers will limit
the number of results returned by the query, and suitable defaults have been
chosen for each supported tracker.

=item B<-e C<bug_matching_perl_regexp>>

The perl regular expression that will match the issue, e.g., /LANG-(\d+)/mi.

=item B<-v C<vcs_type>>

The version control system: git (default) or svn.


=cut
use warnings;
use strict;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;
use Utils;

my %cmd_opts;
getopts('p:n:w:r:g:t:e:q:z:u:l:v:', \%cmd_opts) or pod2usage(1);
pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{n}
                    and defined $cmd_opts{w} and defined $cmd_opts{r}
                    and defined $cmd_opts{g} and defined $cmd_opts{t}
                    and defined $cmd_opts{e};

my $PID = $cmd_opts{p};
my $NAME = $cmd_opts{n};
my $WORK_DIR = abs_path($cmd_opts{w});
my $REPOSITORY_URL = $cmd_opts{r};

my $ISSUE_TRACKER_NAME = $cmd_opts{g};
my $ISSUE_TRACKER_PROJECT_ID = $cmd_opts{t};
my $ISSUES_DIR = "$WORK_DIR/issues";
my $ISSUES_FILE = "$WORK_DIR/issues.txt";
my $ORGANIZATION_ID = $cmd_opts{z};
my $QUERY = $cmd_opts{q};
my $TRACKER_URI = $cmd_opts{u};
my $FETCHING_LIMIT = $cmd_opts{l};

my $REGEXP = $cmd_opts{e};
my $GIT_LOG_FILE = "$WORK_DIR/gitlog";
my $REPOSITORY_DIR = "$WORK_DIR/project_repos/$NAME.git";
my $COMMIT_DB_FILE = "$WORK_DIR/framework/projects/$PID/$BUGS_CSV_ACTIVE";
my $VCS_TYPE = $cmd_opts{v} // "git";

# Configure project for Defects4J
Utils::exec_cmd("./create-project.pl -p $PID"
                                 . " -n $NAME"
                                 . " -w $WORK_DIR"
                                 . " -r $REPOSITORY_URL",
                "Configuring project for Defects4J") or die "Failed to configure project for Defects4J!";

# Does project exist in the Defects4J database? If yes, copy over the required
# (and existing) files to build the project.
if (-e "$CORE_DIR/Project/$PID.pm") {
    # Override project module
    system("cp $CORE_DIR/Project/$PID.pm $WORK_DIR/framework/core/Project/$PID.pm");
    # Override project build file
    system("cp $PROJECTS_DIR/$PID/$PID.build.xml $WORK_DIR/framework/projects/$PID/$PID.build.xml");
}

if (defined($QUERY)) {
    $QUERY = "-q $QUERY";
} else {
    $QUERY = "";
}

my $ORG_ID = "";
if (defined($ORGANIZATION_ID)) {
  $ORG_ID = " -z $ORGANIZATION_ID";
}

# Collect all issues from the project issue tracker
Utils::exec_cmd("./download-issues.pl -g $ISSUE_TRACKER_NAME"
                                  . " -t $ISSUE_TRACKER_PROJECT_ID"
                                  . " -o $ISSUES_DIR"
                                  . " -f $ISSUES_FILE"
                                  . "$ORG_ID"
                                  . "$QUERY",
                "Collecting all issues from the project issue tracker") or die "Cannot collect all issues from the project issue tracker!";

# Collect git log
Utils::exec_cmd("git --git-dir=$REPOSITORY_DIR log --reverse > $GIT_LOG_FILE",
                "Collecting repository log") or die "Cannot collect git history!";
# Cross-reference the commit log with the issue numbers known to be bugs
Utils::exec_cmd("./vcs-log-xref.pl -e '$REGEXP'"
                               . " -l $GIT_LOG_FILE"
                               . " -r $REPOSITORY_DIR"
                               . " -i $ISSUES_FILE"
                               . " -f $COMMIT_DB_FILE",
                "Cross-referencing the commit log with the issue numbers known to be bugs") or die "Cannot collect all issues from the project issue tracker!";

# Does project exist in the Defects4J database? If yes, discard faults that
# have already been mined.
if (-e "$CORE_DIR/Project/$PID.pm") {
    # Remove exiting ids
    system("tail -n +2 $PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE | cut -f 2- -d',' > $COMMIT_DB_FILE.orig");
    # Find all versions that have not been mined
    system("grep -vFf $COMMIT_DB_FILE.orig $COMMIT_DB_FILE > $COMMIT_DB_FILE.filter && mv $COMMIT_DB_FILE.filter $COMMIT_DB_FILE");
}

print("Project $PID has been successfully initialized!\n");
