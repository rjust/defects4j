#!/usr/bin/env perl

=head1 NAME

show_coverage.pl

=head1 SYNOPSIS

show_coverage.pl [options] [optional defects4j coverage file]

 Options:
  -help        brief help message
  -details     include details of each test run
  -man         full documentation

=head1 OPTIONS

=over 4

=item B<-help>

Print a brief help message and exits.

=item B<-details>

Include coverage details for each test.
[default is summary only]

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

This perl script reads a Defects4j coverage file, calculates the percent coverage
and displays the result.

By default, the script will read the file:

  /tmp/test_d4j/coverage

You may supply an alternative file as an argument.

=cut

use strict;
use warnings;

use POSIX qw(strftime);
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);

my $help = 0;
my $details = 0;
my $man = 0;

# Parse options and print usage if there is a syntax error,
# or if usage was explicitly requested.
GetOptions('help|?' => \$help, details => \$details, man => \$man) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-verbose => 2) if $man;
# Check for too many filenames
pod2usage("$0: Too many files given.\n")  if (@ARGV > 1);

# if the number of tests to be run is modified in randoop_coverage.sh,
# then the expected_test_count will need to be modified to match.
my $expected_test_count = 30;
my $test_count = 0;
my $tot_line = 0;
my $tot_exec = 0;
my $tot_fail = 0;
my $filename = '/tmp/test_d4j/coverage';

print(strftime("\nToday's date: %Y-%m-%d %H:%M:%S", localtime), "\n");

if (@ARGV == 1) {
    $filename = $ARGV[0];
}

open(my $fh, '<', $filename)
  or die "Could not open file '$filename'. $!.\n";
printf("Processing file: %s\n", $filename);
print(strftime("Created: %Y-%m-%d %H:%M:%S", localtime((stat($fh))[9])), "\n");

if ($details) {
    print "\nTest    Lines     Total    %", "\n";
    print "name    covered   lines    coverage", "\n";
}

# read all input lines into an array and
# sort it to get consistent output
my @lines = <$fh>;

foreach (sort(@lines)) {
    chomp;
    my @fields = split /,/;
    if (@fields == 0) {
        # do nothing for a blank line
    } elsif ($fields[0] eq "project_id") {
        # do nothing for a header line
    } else {
        $test_count += 1;
        $tot_line += $fields[4];
        $tot_exec += $fields[5];
        if ($details) {
            if ($fields[4] != 0) {
                printf("%s: %d %d %.2f\n", $fields[0].$fields[1], $fields[5], $fields[4], $fields[5]/$fields[4]);
            } else {
                printf("%s: failed\n", $fields[0].$fields[1]);
                $tot_fail += 1;
            }
        }
    }
}

if ($expected_test_count < $test_count) {
    die "More test results than expected!";
}
$tot_fail += $expected_test_count - $test_count;

printf("\nNumber of tests: %d, %d failed\n", $expected_test_count, $tot_fail);
print "Total lines: ", $tot_line, "\n";
print "Lines executed: ", $tot_exec, "\n";
printf("Coverage: %.2f\n", $tot_exec/$tot_line);
