#! /usr/bin/env perl
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

# This is a small auxilary script that merges commit-dbs by adding
# the appropriate numbers to the beginning. The output is specified
# by -f filename, and the input is read from STDIN.

use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Pod::Usage;

sub _usage {
    die "usage: " . basename($0) . " -f filename";
}

my %cmd_opts;
getopt('f:', \%cmd_opts);
my $filename = $cmd_opts{'f'};
_usage() unless defined $filename;

my @existing_commits = (); # assume order of these is not cronological
my $last_number = 0;
if (-e $filename) {
    open FH, $filename;
    while (my $line = <FH>) {
        chomp $line;
        $line =~ /^(\d+),(.*,.*)$/;
        $last_number = $1 if $1 > $last_number; # last number isnt necessary the highest
        push @existing_commits, $2;
    }
    close FH;
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
while (my $line = <STDIN>) {
    chomp $line;
    next unless $line;
    $line =~ /(?:\d+,){0,1}(.+,.+)/; # allows a bugid but will ignore it (this is just a quick adaptation in case you feed a commit-db into this script)
    # TODO check commits if they are non empty
    unshift @new_commits, $1;  # unshift places line at the front
}

# append new bugs to output file
open FH, ">>$filename";
foreach my $line (@new_commits) {
    unless(grep(/$line/,@existing_commits)) { # unless it's already in the file
        ++$last_number;
        print FH "$last_number,$line\n";
        push @existing_commits, $line;
    }
}
close FH;
