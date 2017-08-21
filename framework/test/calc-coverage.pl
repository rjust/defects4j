#!/usr/bin/env perl
use strict;
use warnings;

# perl script to count the number of invariants in a 'run_dyntrace' log file

my $test_count = 0;
my $tot_line = 0;
my $tot_exec = 0;
my @fields;

    while (<>) {
        chomp;
        @fields = split /,/;
            if (@fields == 0) {
                # do nothing for a blank line
            } elsif ($fields[0] eq "project_id") {
                # do nothing for a header line
            } else {
                $test_count += 1;
                $tot_line += $fields[4];
                $tot_exec += $fields[5];
            }
    }
    print "Number tests: ", $test_count, "\n";
    print "Total lines: ", $tot_line, "\n";
    print "Lines executed: ", $tot_exec, "\n";
    printf("Coverage: %.2f\n", $tot_exec/$tot_line);
