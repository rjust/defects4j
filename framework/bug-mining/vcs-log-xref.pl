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

vcs-log-xref.pl -- Parses the development history log for a project screening it
with a regular expression, and validates that they pass a test provided by a
script that can verify they are bugs (as opposed to improvements, pull requests,
etc.)

=head1 SYNOPSIS

vcs-log-xref.pl -v vcs_type -e bug_matching_perl_regexp -l commit_log -r repository_dir -c command_to_verify -f output_file

=head1 OPTIONS

=over 4

=item B<-t C<vcs_type>>

The version control system, i.e., git or svn.

=item B<-e C<bug_matching_perl_regexp>>

The perl regular expression that will match the issue, e.g., /LANG-(\d+)/mi.

=item B<-l C<commit_log>>

The part of the development history that you wish to cross-reference with an
issue tracker. This file may be obtained for example by running C<git log>.

=item B<-r C<repository_dir>>

The path to the git repo for this project (this argument is ignored for SVN
repositories).

=item B<-c C<command_to_verify>>

The command to run that will verify whether a given issue ID is a bug. The
bug-mining framework currently supplies two auxillary scripts
(C<verify-bug-file.sh> and C<verify-bug-sf-tracker.sh>) that help with this
task. You may also supply your own.

=cut
use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use List::Util qw(all pairmap);
use Pod::Usage;

my %SUPPORTED_VCSs = (
    'git' => {
            'get_commits' => sub {
                            my ($fh, $command, $regexp) = @_;
                            die unless all {defined $_} ($fh, $command, $regexp);
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
                                    next unless system("${command} ${bug_number}") == 0; # skip bug ids that do not
                                                                                         # pass the test

                                    my $parent = _git_get_parent($commit);
                                    next unless $parent; # skip revisions without parent:
                                                         # this can be the first revision or
                                                         # due to bad history rewriting
                                    $results{$version_id}{'p'} = $parent;
                                    $results{$version_id}{'c'} = $commit;
                                    $commit = '';        # unset to skip lines until next commit

                                    $version_id += 1; # increase version id
                                }
                            }
                            return \%results;
                }
        },
    'svn' => {
            'get_commits' => sub {
                                my ($fh, $command, $regexp) = @_;
                                die unless all {defined $_} ($fh, $command, $regexp);
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
                                        next unless system("${command} ${bug_number}") == 0; # skip bug ids that do not
                                                                                             # pass the test

                                        my $parent = $commit - 1;
                                        next unless $parent > 0; # skip first revision
                                        $results{$version_id}{'p'} = $parent;
                                        $results{$version_id}{'c'} = $commit;
                                        $commit = '';        # unset to skip lines until next commit

                                        $version_id += 1; # increase version id
                                    }
                                }
                                return \%results;
                    }
        }
);

my %cmd_opts;
getopts('v:e:l:r:c:f:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{v} and defined $cmd_opts{e}
                    and defined $cmd_opts{l} and defined $cmd_opts{c};

my $VCS_NAME = $cmd_opts{v};
if (! defined $SUPPORTED_VCSs{$VCS_NAME}) {
    die "Invalid vcs-name! Expected one of the following options: " . join ('|', sort keys (%SUPPORTED_VCSs)) . ".";
}
my %VCS = %{$SUPPORTED_VCSs{$VCS_NAME}};

my $REGEXP = $cmd_opts{e};
my $LOG_FILE = $cmd_opts{l};
my $REPOSITORY_DIR = $cmd_opts{r};
my $COMMAND = $cmd_opts{c};
my $OUTPUT_FILE = $cmd_opts{f};

open my $fh, $LOG_FILE or die "Could not open commit-log $LOG_FILE";
my %commits = %{$VCS{'get_commits'}($fh, $COMMAND, $REGEXP)};
close $fh;
if (scalar keys %commits eq 0) {
    print("Warning, no commit that matches the regex expression provided has been found\n");
}
open $fh, ">$OUTPUT_FILE" or die "Cannot open ${OUTPUT_FILE}!";
for my $commit_id (sort { $a <=> $b} keys %commits) {
    print $fh "$commit_id,$commits{$commit_id}{'p'},$commits{$commit_id}{'c'}\n";
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
