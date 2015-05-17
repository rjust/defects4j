#! /usr/bin/env perl
# This is a small auxilary script that merges commit-dbs by adding
# the appropriate numbers to the beginning. The output is specified
# by -f filename, and the input is read from STDIN.

use strict;
use warnings;

use File::Basename;
use Getopt::Std;

sub _usage {
    die "usage: " . basename($0) . " -f filename";
}

my %cmd_opts;
getopt('f:', \%cmd_opts);
my $filename = $cmd_opts{'f'};
_usage() unless defined $filename;

my %existing_commits = ();
my $last_number = 0;
if (-e $filename) {
    open FH, $filename;
    while (my $line = <FH>) {
        chomp $line;
        $line =~ /^(\d+),(.*,.*)$/;
        $last_number = $1;
        $existing_commits{$2} = 1;
    }
    close FH;
}

open FH, ">>$filename";
while (my $line = <STDIN>) {
    chomp $line;
    next unless $line;
    ++$last_number;
    print FH "$last_number,$line\n" unless $existing_commits{$line};
    $existing_commits{$line} = 1;
}
close FH;
