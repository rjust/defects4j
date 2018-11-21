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

merge-commit-db.pl -- Merge commit-dbs by adding the appropriate numbers to the
beginning. The output is specified by -f F<output_file>, and the input is read
from STDIN. # FIXME it should not be from STDIN

=head1 SYNOPSIS

merge-commit-db.pl -g git_dir -t tracker_project_id -f output_file [-s src_dir]

=head1 OPTIONS

=over 4

=item B<-g F<git_dir>>

# TODO

=item B<-t C<tracker_project_id>>

# TODO

=item B<-f F<output_file>>

# TODO

=item B<-s F<source_dir>>

# TODO

=back

=cut
use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Pod::Usage;

my %cmd_opts;
getopts('g:t:f:s:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{g} and defined $cmd_opts{t} and defined $cmd_opts{f};

my $GIT_DIR = $cmd_opts{g};
my $TRACKER_ID = $cmd_opts{t}; # TODO why do we need a tracker id in this script?
my $OUTPUT_FILE = $cmd_opts{f};
my $SRC = defined $cmd_opts{s} ? $cmd_opts{s} : 'src';

my @existing_commits = (); # assume order of these is not cronological
my $last_number = 0;
if (-e $FILE) { # FIXME $FILE should be the current 'commit-db'
    open(FH, $FILE);
    while (my $line = <FH>) {
        chomp $line;
        $line =~ /^(\d+),(.*,.*)$/;
        $last_number = $1 if $1 > $last_number; # last number isnt necessary the highest
        push @existing_commits, $2;
    }
    close(FH);
}

# existing bugs must keep bug id the same
# however new bugs will be issued a numerically higher bug id meaning newer bugs have newer bug ids
# but the old system had lower numbers as newer
# example bugid,date
# 1,2015
# 2,2014
# 3,2013 //end of old system
# 4,2016 //start of new system
# 5,2017

# buffer incomming revision ids
# STDIN will stream commits newest to oldest
my @new_commits = (); # likely will be duplicates in @existing_commits
my $filtered_commits = 0;
my $existing_commits_count = scalar @existing_commits;
while (my $line = <STDIN>) { # FIXME <STDIN> should be a new 'commit-db'
    chomp $line;
    next unless $line;
    $line =~ /(?:\d+,){0,1}(.+),(.+)(?:,.+)*/; # allows a bugid and other random params but will ignore them (this is just a quick adaptation in case you feed a commit-db into this script)
    # check commits src dir if they are non empty before merging
    unless(`git --git-dir=$git_dir --no-pager diff --binary $2 $1 -- $src $src` eq "") { # buggy to fixed
        unshift @new_commits, "$1,$2";  # unshift places line at the front
    } else {
        $filtered_commits++;
    }
}

# append new bugs to output file
open(FH, ">>$filename"); # FIXME append to the current commit-db
foreach my $line (@new_commits) {
    unless(grep(/$line/,@existing_commits)) { # unless it's already in the file
        ++$last_number;
        print FH "$last_number,$line,$tracker_id\n";
        push @existing_commits, $line;
    }
}
close(FH);

print "Bugs filtered (empty src diff): $filtered_commits\n";
my $total_commits = scalar @existing_commits;
my $added_commits = $total_commits - $existing_commits_count;
print "Bugs added: $added_commits\n";
print "Total bugs: $total_commits\n";
