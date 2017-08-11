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

rm_broken_tests.pl -- remove broken test methods from a set of test classes.

=head1 SYNOPSIS

    rm_broken_tests.pl log_file src_dir [except]

=head1 DESCRIPTION

Parses the file F<log_file> and fixes failing test methods by replacing each broken test
method with a dummy test method in the source file of the corresponding test class. The
source file of the test class is backed up prior to the first modification. If except is
provided, then this test is mainted even if it appears in the log file.

=cut
#
# TODO: This file needs a thorough overhaul and its command-line interface is not
#       Defects4J standard!
#
use IO::File;
use File::Copy;
use Text::Balanced qw (extract_bracketed);
use warnings;
use strict;

($#ARGV==1 || $#ARGV==2) or die "usage: $0 log_file src_dir [except]";

my $log_file = shift @ARGV;
my $base_dir = shift @ARGV;
my $except   = shift @ARGV;

my $verbose = 0;

-e $log_file or die "Cannot open log file: $!";

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
my @list = `grep -a "^---" $log_file | sort -u -k1 -t":"`;

my $counter=0;
my @tests;

# Check all entries in the log file
for (@list) {
    /--- ([^:]+)(::([^:]+))?/ or die "Corrupted log file: $_";
}

my %buffers;

# Cache the entire log file for stack trace analysis
open FILE, $log_file or die "Cannot open log file ($log_file): $!";
my @log_lines = <FILE>;
close FILE;

# TODO: Remove this hack once the command-line interface has been updated.
my $RM_ASSERTS = (defined $ENV{D4J_RM_ASSERTS} && $ENV{D4J_RM_ASSERTS} == 1) ? 1 : 0;

# This variable is used to keep track of whether this program uses
# junit 4 styles. This is important, since the @Test annotation
# must not be added on empty method additions for superclass
# failing methods
# This hash will map a filename to 1 in case it is junit 4.
my %is_buffer_junit4 = ();

my @method_list=();
for (@list){
    chomp;
    /--- ([^:]+)(::([^:]+))?/;
    my $class  = $1;
    my $method = $3;
    _exclude_test_class($class) unless defined $method;

    if ($except) {
        next if "$class::$method" eq $except;    # skip the excepted test.
    }

    my $file = $class;
    $file =~ s/\./\//g;
    $file = "$base_dir/$file.java";

    # Skip non-existing files
    if (! -e $file) {
        print STDERR "$0: $file does not exist -> SKIP ($method)\n" if $verbose;
        next;
    }

    # Backup file if necessary
    if (! -e "$file.bak") {
        copy("$file","$file.bak") or die "Cannot backup file ($file): $!";
    }

    # Buffer file for modifications
    _buffer_file($file);

    if (defined $method) {
        # Check wether removing failing assertions is enabled and successful
        unless ($RM_ASSERTS && _remove_assertion($class, $method)) {
            push(@method_list, $_);
        }
    }
}

# Remove the remaining test methods -- the ones for which we couldn't remove the failing
# assertion.
for (@method_list) {
    /--- ([^:]+)(::([^:]+))?/;
    my $class  = $1;
    my $method = $3;
    _remove_test_method($class, $method);
}

# Write file buffers
_write_buffers();

0;

sub _exclude_test_class {
    my $class = shift;
    # We do not remove broken test classes as
    # this might cause compilation issues
}

# TODO: Use Utils::get_failing_tests to obtain information about failing assertions
sub _remove_assertion {
    my ($class, $method) = @_;
    my $file = $class;
    $file =~ s/\./\//g;
    $file = "$base_dir/$file.java";

    for (my $i=0; $i <= $#log_lines; ++$i) {
        local $_ = $log_lines[$i];
        chomp;
        /--- $class::$method/ or next;
        # Read first line of stack trace to determine the failure reason.
        my $reason = $log_lines[$i+1];
        if (defined $reason and $reason =~ /junit.framework.AssertionFailedError/) {
            $class =~ /(.*\.)?([^.]+)/ or die "Couldn't determine class name: $class!";
            my $classname = $2;
            ++$i;
            while ($log_lines[$i] !~ /---/) {
                if ($log_lines[$i] =~ /junit\./) {
                    # Skip junit entries in the stack trace
                    ++$i;
                } elsif ($log_lines[$i] =~ /$classname\.java:(\d+)/) {
                    # We found the right entry in the stack trace
                    my $line = $1;
                    # Check whether this line looks like an assertion, if so remove it.
                    if ($buffers{$file}->[$line-1] =~ /assert.*\(.*\)/) {
                        $buffers{$file}->[$line-1] = "// Defects4J: flaky assertion --> " . $buffers{$file}->[$line-1];
                        return 1;
                    }
                    last;
                } else {
                    # The stack trace isn't what we expected -- give up and continue
                    # with the next triggering test
                    last;
                }
            }
        }
    }

    return 0;
}

sub _remove_test_method {
    my ($class, $method) = @_;
    my $file = $class;
    $file =~ s/\./\//g;
    $file = "$base_dir/$file.java";

    my @lines=@{$buffers{$file}};
    # Line buffer for the fixed source file
    my @buffer;
    for (my $i=0; $i<=$#lines; ++$i) {
        if ($lines[$i] =~ /^([^\/]*)public.+$method\(\)/) {
            my $index = $i;
            # Found the test to exclude
            my $space = $1;
            # Dummy test
            my $dummy = "${space}public void $method() {}\n// Defects4J: flaky method\n";
            # Check whether JUnit4 annotation is present
            if ($lines[$i-1] =~ /\@Test/) {
                $dummy = "${space}\@Test\n$dummy";
                --$index;
            }

            # Remove all String/Character literals and comments from the
            # temporary buffer as they may contain unbalanced delimiters or
            # brackets.
            #
            # TODO: This is a rather hacky solution. We should think about a
            # proper parser that computes a line-number table for all methods.
            my @tmp = @lines[$index..$#lines];
            foreach (@tmp) {
                # This captures String literals -- accounting for escaped quotes
                # (\") and non-escaped quotes (" and \\")
                s/([\"'])(?:(?<!\\)\\\1|.)*?\1/$1$1/g;
                s/\/\/.*/\/\//;
            }

            my @result = extract_bracketed(join("", @tmp), '{"\'}', '[^\{]*');
            die "Could not extract method body for $class::$method" unless defined $result[0];

            my $len = scalar(split("\n", $result[2].$result[0]));

            # Add everything before broken method
            push(@buffer, @lines[0..($index-1)]);
            # Add dummy method
            push(@buffer, $dummy);
            # Comment out broken method
            foreach (@lines[$index..($index+$len-1)]) {
                push(@buffer, "// $_");
            }
            # Add everything after broken method
            push(@buffer, @lines[($index+$len)..$#lines]);

            last;
        }
    }

    if (@buffer) {
        # Update file buffer
        $buffers{$file} = \@buffer;
    } else {
        # Override failing test method if it was implemented in super class
        my $override = ###### "    \@Override\n" .
                       ###### TODO: There is a problem with adding the @Override annotation
                       #              it is that when we are dealing with e.g, broken_tests
                       #              and specify them project wide, it may be that
                       #              the file exists but not the method, so we
                       #              don't find it and assume it was in the super class
                       #              This is different than the case when we know it is
                       #              failing for this particular revision.
                       "    public void $method() {} // Fails in super class\n";

        # Only add @Test annotation if we are using Junit 4
        $override =       "    \@Test\n" . $override if $is_buffer_junit4{$file};


        # Read file buffer, determine closing curly brace of test class,
        # and insert test method before the brace.
        # TODO: This is probably not the most elegant solution.
        my @buffer = @{$buffers{$file}};
        for (my $index=$#buffer; $index>=0; --$index) {
            # Find closing curly
            next unless $buffer[$index] =~ /}/;
            # Insert dummy (empty) test method
            $buffer[$index] =~ s/^(.*)}([^}])$/$1\n$override}$2/;
            $buffers{$file} = \@buffer;

            last;
        }
    }
}

sub _buffer_file {
    my $file = shift;
    if (!defined($buffers{$file})) {
        # Read the entire file
        my $in = IO::File->new("<$file") or die "Cannot open source file: $file!";
        my @data = <$in>;
        $in->close();
        $buffers{$file}=\@data;

        # Check for junit 4
        $is_buffer_junit4{$file} = 0;
        $is_buffer_junit4{$file} = 1 if grep {/import org\.junit\.Test/} @data;
    }
}


sub _write_buffers {
    sleep(1);
    foreach my $file (keys %buffers) {
        my @buffer = @{$buffers{$file}};
        unlink($file);
        my $fix = IO::File->new(">$file") or die "Cannot write source file: $file!";
        print $fix @buffer;
        $fix->flush();
        $fix->close();
    }
}
