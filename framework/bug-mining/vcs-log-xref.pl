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

vcs-log-xref.pl -- Parses the development history log for a project screening it
with a regular expression, and validates that bug-fixing commits have been
reported in the project issue tracker.

=head1 SYNOPSIS

vcs-log-xref.pl -e bug_matching_perl_regexp -l commit_log -r repository_dir -i issues_file -f output_file [-v vcs_type] [-n project_name]

=head1 OPTIONS

=over 4

=item B<-e C<bug_matching_perl_regexp>>

The perl regular expression that will match the issue, e.g., /LANG-(\d+)/mi.

=item B<-l C<commit_log>>

The part of the development history that you wish to cross-reference with an
issue tracker. This file may be obtained for example by running C<git log>.

=item B<-r C<repository_dir>>

The path to the git repository for this project (this argument is ignored for SVN
repositories).

=item B<-i C<issues_file>>

The file with all issues that have been reported in the project issue tracker.
Each row of the file has two values separated by ',': <issue id>,<issue url>.

=item B<-f C<output_file>>

The file to which all revision ids of the pre-fix and post-fix revision are written.
Each row of the file is composed by 5 values:
  <d4j_bug_id, bug_commit_hash, fix_commit_hash, issue_id, issue_url>

=item B<-v C<vcs_type>>

The version control system: git (default) or svn.

=item B<-n C<project_name>>

The (descriptive) name of the new project (e.g., commons-lang).

=cut
use strict;
use warnings;

use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use List::Util qw(all pairmap);
use Pod::Usage;

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Utils;

my %SUPPORTED_VCSs = (
    'git' => {
            'get_commits' => sub {
                            my ($fh, $project_name, $regexp, $issues_file, $issues_db) = @_;
                            die unless all {defined $_} ($fh, $regexp, $issues_file, $issues_db);
                            my %results;
                            my $commit = '';
                            my $version_id = 1;
                            while (<$fh>) {
                                chomp ;
                                if (/^commit (.*)/) {
                                    <$fh>; # author line -> uninteresting
                                    <$fh>; # date line   -> uninteresting
                                    $commit = $1;
                                    next;
                                }
                                next unless $commit; # skip lines before first commit info.
                                if (my $bug_number = eval('$_ =~' . "$regexp" . '; $1')) {
                                    # skip bug ids that have not been reported in the issue tracker
                                    next unless system("grep -qi \"^${bug_number},\" $issues_file") == 0;
                                    my $parent = _git_get_parent($commit);
                                    next unless $parent; # skip revisions without parent:
                                                         # this can be the first revision or
                                                         # due to bad history rewriting
                                    $results{$version_id}{'p'} = $parent;
                                    $results{$version_id}{'c'} = $commit;
                                    $results{$version_id}{'issue_id'} = $bug_number;
                                    $results{$version_id}{'issue_url'} = $issues_db->{lc($bug_number)} // undef;

                                    $commit = '';        # unset to skip lines until next commit
                                    $version_id += 1; # increase version id
                                }
                            }
                            return \%results;
                }
        },
    'svn' => {
            'get_commits' => sub {
                                my ($fh, $project_name, $regexp, $issues_file, $issues_db) = @_;
                                die unless all {defined $_} ($fh, $project_name, $regexp, $issues_file, $issues_db);
                                my %results;
                                my $commit = '';
                                my $version_id = 1;
                                while (<$fh>) {
                                    chomp;
                                    if (/^r(\d+) \| .* \| \d+ line/) {
                                        $commit = $1;
                                        next;
                                    }
                                    next unless $commit; # skip lines before first commit info.
                                    if (my $bug_number = eval('$_ =~' . "$regexp" . '; $1')) {
                                        # skip bug ids that have not been reported in the issue tracker
                                        next unless system("curl -s -S -L -o /dev/null \"https://sourceforge.net/p/$project_name/bugs/$bug_number\"") == 0;
                                        my $parent = $commit - 1;
                                        next unless $parent > 0; # skip first revision
                                        $results{$version_id}{'p'} = $parent;
                                        $results{$version_id}{'c'} = $commit;
                                        $results{$version_id}{'issue_id'} = $bug_number;
                                        $results{$version_id}{'issue_url'} = $issues_db->{lc($bug_number)} // undef;

                                        $commit = '';        # unset to skip lines until next commit
                                        $version_id += 1; # increase version id
                                    }
                                }
                                return \%results;
                    }
        }
);

my %cmd_opts;
getopts('e:l:r:i:f:v:n:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{e} and defined $cmd_opts{l}
                    and defined $cmd_opts{r} and defined $cmd_opts{i}
                    and defined $cmd_opts{f};

my $VCS_NAME = $cmd_opts{v} // "git";
if (! defined $SUPPORTED_VCSs{$VCS_NAME}) {
    die "Invalid vcs-name! Expected one of the following options: " . join ('|', sort keys (%SUPPORTED_VCSs)) . ".";
}
my %VCS = %{$SUPPORTED_VCSs{$VCS_NAME}};

my $REGEXP = $cmd_opts{e};
my $LOG_FILE = $cmd_opts{l};
my $REPOSITORY_DIR = $cmd_opts{r};
my $ISSUES_FILE = abs_path($cmd_opts{i});
my $OUTPUT_FILE = $cmd_opts{f};
my $PROJECT_NAME = $cmd_opts{n};

# Issues file must exist and it can be empty
if (! -s $ISSUES_FILE) {
    die "$ISSUES_FILE does not exist or it is empty";
}
# Cache content of issues.txt file
my $ISSUES_DB = Utils::read_config_file($ISSUES_FILE, ",") or die "Failed to read the content of $ISSUES_FILE";
# Lowercase keys as different variations might exist in different commit messages
%$ISSUES_DB = map { lc($_) => $ISSUES_DB->{$_} } keys %$ISSUES_DB;

open my $fh, $LOG_FILE or die "Could not open commit-log $LOG_FILE";
my %commits = %{$VCS{'get_commits'}($fh, $PROJECT_NAME, $REGEXP, $ISSUES_FILE, $ISSUES_DB)};
close $fh;
if (scalar keys %commits eq 0) {
    print("Warning, no commit that matches the regex expression provided has been found\n");
}
open $fh, ">>$OUTPUT_FILE" or die "Cannot open ${OUTPUT_FILE}!";
for my $commit_id (sort { $a <=> $b} keys %commits) {
    my $row = $commits{$commit_id};
    print $fh "$commit_id,$row->{'p'},$row->{'c'},$row->{'issue_id'},$row->{'issue_url'}\n";
}
close($fh);

sub _git_get_parent {
    my $commit = shift;
    die unless $commit;
    my @parents = _git_get_parent_revisions($commit);
    die "too many parents" unless (@parents == 1);
    return $parents[0];
}

sub _git_get_parent_revisions {
    my $revision_no = shift;
    die unless $revision_no;
    # returns a string <revision-no> <parent1> <parent2> <parent3> ...
    my $result = `git --git-dir=${REPOSITORY_DIR} rev-list --parents -n 1 ${revision_no}`;
    die unless $? == 0;
    chomp $result;
    die "Could not run git" unless $? == 0;
    my @split_var = split / /, $result;
    return @split_var[1,]
}
