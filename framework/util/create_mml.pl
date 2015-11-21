#!/usr/bin/env perl
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

=pod

=head1 NAME

create_mml.pl -- create a Major-compatible MML file, which defines program mutations.

=head1 SYNOPSIS

  create_mml.pl -p project_id -c classes_dir -o out_dir [-b bug_id]

=head1 DESCRIPTION

Generates an MML file for every bug id listed in F<classes_dir> -- for every bug id, a list
of classes that should be mutated has to be provided in a file with the following name:
F<C<bug_id>.src>.
The generated MML files are named F<C<bug_id>.mml> and written to F<out_dir>.

=head1 OPTIONS

=over 4

=item -p C<project_id>

The id of the project for which the MML file is generated.
See L<Project|Project/"Available Project IDs"> module for available project IDs.

=item -b C<bug_id>

The bug id for which the MML file is generated (optional). Format: C<\d+>.

=item -c F<classes_dir>

The directory that contains the lists of classes that should be mutated.

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
use Utils;

#
# Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('p:c:o:b:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{c} and defined $cmd_opts{o};

my $PID = $cmd_opts{p};
my $CLASS_DIR = Utils::get_abs_path($cmd_opts{c});
my $OUT_DIR = Utils::get_abs_path($cmd_opts{o});
my $BID = $cmd_opts{b};

if (defined $BID) {
    $BID =~ /^(\d+)$/ or die "Wrong bug id format (\\d+): $BID!";
}
-e $CLASS_DIR or die "Directory with lists of classes does not exist: $CLASS_DIR";

my $TEMPLATE = `cat $MAJOR_ROOT/mml/template.mml` or die "Cannot read mml template: $!";

# The mutation operators that should be enabled in the mml file
my @ops =("AOR", "LOR","SOR", "COR", "ROR", "ORU", "LVR", "STD");

system("mkdir -p $OUT_DIR");

my @ids;
# Use specific bug id
if (defined $BID) {
    @ids = ($BID);
} else {
    @ids = _get_bug_ids();
}

foreach my $bid (@ids) {
    my @classes = _get_classes_list($bid);
    my $file = "$OUT_DIR/$bid.mml";

    # Generate mml file by enabling operators for listed classes only
    open(FILE, ">$file") or die "Cannot write mml file ($file): $!";
    # Add operator definitions from template
    print FILE $TEMPLATE;
    # Enable operators for all classes
    foreach my $class (@classes) {
        print FILE "\n// Enable operators for $class\n";
        foreach my $op (@ops) {
            # Skip disabled operators
            next if $TEMPLATE =~ /-$op<"$class">/;
            print FILE "$op<\"$class\">;\n";
        }
    }
    close(FILE);
    my $log = `$MAJOR_ROOT/bin/mmlc $file 2>&1`;
    $? == 0 or die "Cannot compile mml file: $file\n$log";
}

#
# Return list of all classes that should be mutated for a given bug id
#
sub _get_classes_list {
    my $bid = shift;
    my $list = `cat $CLASS_DIR/$bid.src`;
    $? == 0 or die "Cannot read classes list for bug id: $bid!";
    return split("\n", $list);
}

#
# Get all bug ids for which we have a list of classes
#
sub _get_bug_ids {
    opendir(DIR, $CLASS_DIR);
    my @files = readdir(DIR);
    closedir(DIR);
    my @ids = ();
    foreach (@files) {
        /(\d+)\.src/ or next;
        push(@ids, $1);
    }
    return @ids;
}
