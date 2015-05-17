#! /usr/bin/env perl
# This is a small auxilary script that merges issue numbers by adding
# only ones that are new. The output is specified
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

my %existing_issues = ();
if (-e $filename) {
    open FH, $filename;
    while (my $line = <FH>) {
        chomp $line;
        $existing_issues{$line} = 1;
    }
    close FH;
}

open FH, ">>$filename";
while (my $line = <STDIN>) {
    chomp $line;
    next unless $line;
    print FH "$line\n" unless $existing_issues{$line};
    $existing_issues{$line} = 1;
}
close FH;
