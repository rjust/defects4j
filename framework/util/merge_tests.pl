#!/usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2017 René Just, Darioush Jalali, and Defects4J contributors.
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

merge_tests.pl -- Replace test methods from a set of test classes with a different version.

=head1 SYNOPSIS

merge_tests.pl log_file target_src_dir other_src_dir [test_name]

=head1 DESCRIPTION

Parses the file F<log_file> and replaces failing test methods in C<target_src_dir>
by replacing the body of each broken test method in the source file with the body
of the corresponding source file in C<other_src_dir>. The source file of the test
class is backed up prior to the first modification.

If F<test_name> is specified, only that test is replaced. F<test_name> must be in
the format of classname::methodname.

=cut

use File::Copy;
use Text::Balanced qw (extract_bracketed);
use warnings;
use strict;

($#ARGV==2 || $#ARGV==3) or die "usage: $0 log_file target_src_dir other_src_dir [test_name]";

my $log_file = shift @ARGV;
my $base_dir = shift @ARGV;
my $other_dir= shift @ARGV;
my $test_name= shift @ARGV;

-e $log_file or die "Cannot open log file: $!";
-e $base_dir or die "Target src dir does not exist: $!";
-e $other_dir or die "Other src dir does not exist: $!";

=pod

The log file may contain arbitrary lines -- the script only considers lines that
match the pattern: B</--- ([^:]*)(::(.*))?/>.

=head3 Example entries in the log file

=over

=item Failing test class: --- package.Class

=item Failing test method: --- package.Class::method

=back

All lines matching the pattern are sorted, such that a failing test class in the
list will appear before any of its failing methods.

=cut
my @list = `grep "^---" $log_file | sort -u -k1 -t":"`;

my @tests;

# Check all entries in the log file
for (@list) {
    /--- ([^:]+)(::([^:]+))?/ or die "Corrupted log file!";
}

for (@list) {
    chomp;
    /--- ([^:]+)(::([^:]+))?/;
    my $class = $1;
    my $method = $3;
    next unless defined $method;
    if ($test_name) {
        next unless "$1::$3" eq $test_name;
    }

    my $file = $class;
    $file =~ s/\./\//g;

    my $file1 = "$base_dir/$file.java";
    my $file2 = "$other_dir/$file.java";

    open(IN, "<$file1") or die $!; my @lines1 = <IN>; close IN;
    open(IN, "<$file2") or die $!; my @lines2 = <IN>; close IN;

    my @target = _get_method($method, @lines1);
    my @other = _get_method($method, @lines2);

    # Check whether method exists in both classes
    if (!@target or !@other) {
        exit 1;
    }

    # Check whether methods differ
    if (scalar(@target) == scalar(@other)) {
        my $equal = 1;
        for (my $i=0; $i<scalar(@target); ++$i) {
            if ($target[$i] ne $other[$i]) {
                $equal = 0; last;
            }
        }
        exit 2 if $equal;
    }

    # Replace target method with other
    _replace_method($file1, $method, \@other, @lines1);
}
0;

sub _replace_method {
    my ($file, $method, $method_other, @class) = @_;

    # Backup file if necessary
    if (! -e "$file.bak") {
        copy("$file","$file.bak") or die "Cannot backup file ($file): $!";
    }

    open(OUT, ">$file") or die $!;

    for (my $i=0; $i<=$#class; ++$i) {
        if ($class[$i] =~ /^([^\/]*)public.+$method\(\)/) {
            my $index = $i;
            # Found the test to exclude
            my $space = $1;
            # Check whether JUnit4 annotation is present
            if ($class[$i-1] =~ /\@Test/) {
                --$index;
            }

            # Remove all comments as they may contain unbalanced delimiters
            # or brackets
            my @tmp = @class[$index..$#class];
            foreach (@tmp) {
                s/^\s*\/\/.*/\/\//;
            }

            my @result = extract_bracketed(join("", @tmp), '{"\'}', '[^\{]*');
            die "Could not extract method body" unless defined $result[0];

            my $len = scalar(split("\n", $result[2].$result[0]));

            # Print everything before broken method
            print OUT @class[0..($index-1)];
            # Print replacement method
            foreach (@{$method_other}) {
                print OUT "$_";
            }
            # Comment out broken method
            foreach (@class[$index..($index+$len-1)]) {
                print OUT "// $_";
            }
            # Print everything after broken method
            print OUT @class[($index+$len)..$#class];

            last;
        }
    }
    close(OUT);
}

#
# Returns the test method with the name "$method_name" in "$class" if it exists
#
sub _get_method {
    my ($method_name, @class) = @_;

    my @method;
    for (my $i=0; $i<=$#class; ++$i) {
        if ($class[$i] =~ /^([^\/]*)public.+$method_name\(\)/) {
            # Found the test
            my $index = $i;
            # Check whether JUnit4 annotation is present
            if ($class[$i-1] =~ /\@Test/) {
                --$index;
            }

            # Remove all comments as they may contain unbalanced delimiters
            # or brackets
            my @tmp = @class[$index..$#class];
            foreach (@tmp) {
                s/^\s*\/\/.*/\/\//;
            }
            my @result = extract_bracketed(join("", @tmp), '{"\'}', '[^\{]*');
            die "Could not extract method body" unless defined $result[0];

            my $len = scalar(split("\n", $result[2].$result[0]));
            @method = @class[$index..($index+$len-1)];
            last;
        }
    }
    return @method;
}
