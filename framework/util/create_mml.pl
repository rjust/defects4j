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

create_mml.pl -- create a Major-compatible MML file, which defines program mutations.

=head1 SYNOPSIS

  create_mml.pl -p project_id -c classes_list -o out_dir -b bug_id

=head1 DESCRIPTION

Generates an MML file for the given C<bug_id>. The file F<classes_list> has to proivde the
list of classes that should be mutated.
The generated MML file is named F<C<bug_id>.mml> and written to F<out_dir>.

=head1 OPTIONS

=over 4

=item -p C<project_id>

The id of the project for which the MML file is generated.
See L<Project|Project/"Available Project IDs"> module for available project IDs.

=item -b C<bug_id>

The bug id for which the MML file is generated. Format: C<\d+>.

=item -c F<classes_list>

The file contains all classes that should be mutated -- one class per line.

=item -o F<out_dir>

The output directory to which the generated MML files are written.

=back

=cut
use warnings;
use strict;

use FindBin;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Mutation;
use Utils;

#
# Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('p:c:o:b:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{c} and defined $cmd_opts{o} and defined $cmd_opts{b};

# TODO: Unused parameter: PID
my $PID = $cmd_opts{p};
my $CLASSES = Utils::get_abs_path($cmd_opts{c});
my $OUT_DIR = Utils::get_abs_path($cmd_opts{o});
my $BID = $cmd_opts{b};

$BID =~ /^(\d+)$/ or die "Wrong bug id format (\\d+): $BID!";
-e $CLASSES or die "File with classes to mutate does not exist: $CLASSES";

# The mutation operators that should be enabled
my @MU_OPS = ("AOR", "LOR","SOR", "COR", "ROR", "ORU", "LVR", "STD");

my $mml_src = "$OUT_DIR/$BID.mml";
my $mml_bin = "${mml_src}.bin";

Mutation::create_mml($CLASSES, $mml_src, \@MUT_OPS);
-e "$mml_bin" or die "Mml file does not exist: $mml_bin!";
