#! /usr/bin/env perl

# this script verifies that the output of the Formatter conforms to the expected
# results.  It performs a basic line matching without considering order.

use strict;
use warnings;

my $expected_fn = "expected-output.txt";
my $output_fn   = "failing-tests.txt";

my $expected = read_file ($expected_fn);
my $output = read_file($output_fn);

for (keys %{$expected}) {
    die "Element in expected not in output: $_" unless defined $output->{$_}; 
}

for (keys %{$output}) {
    die "Element in output not in expected: $_" unless defined $expected->{$_}; 
};

sub read_file {
    my $fn = shift @_;
    open(IN, "<$fn") or die "Cannot read file ($fn): $!";
    my $buf = {};
    while (<IN>) {
        next unless /---/;
        $buf->{$_} = 1;
    }
    close(IN);
    return $buf;
}
