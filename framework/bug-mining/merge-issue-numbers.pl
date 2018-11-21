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

merge-issue-numbers.pl -- Merge issue numbers by adding only ones that are new.
The output is specified by -f filename, and the input is read from STDIN.
# TODO it should not be from STDIN.

=head1 SYNOPSIS

merge-issue-numbers.pl -f issues_file

=head1 OPTIONS

=over 4

=item B<-f F<issues_file>>

The file with all issues ids.

=back

=cut
use strict;
use warnings;

use File::Basename;
use Getopt::Std;
use Pod::Usage;

my %cmd_opts;
getopts('f:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{f};

my $FILENAME = $cmd_opts{f};

my %existing_issues = ();
if (-e $FILENAME) {
    open FH, $FILENAME;
    while (my $line = <FH>) {
        chomp $line;
        $existing_issues{$line} = 1;
    }
    close FH;
}

open FH, ">>$FILENAME";
while (my $line = <STDIN>) { # FIXME it should not be from STDIN
    chomp $line;
    next unless $line;
    print FH "$line\n" unless $existing_issues{$line};
    $existing_issues{$line} = 1;
}
close FH;
