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

create_mml.pl -- Create mml files for all program revisions with reproducible bugs.

=head1 SYNOPSIS

create_mml.pl -p project_id -c class_dir -o out_dir [-v version_id]

=head1 DESCRIPTION

Generates a mml file for every list of project-related classes in
C<class_dir> -- a list of classes has to be provided in a file with the
following naming convention:
B<"version_id".src>.
The generated mml files are named "version_id".mml and written to C<out_dir>.

If the C<version_id> is provided in addition to the C<project_id>, then only
this C<version_id> is considered for the project.

=cut
use warnings;
use strict;

use FindBin;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;

use lib abs_path("$FindBin::Bin/../core");
use Constants;

#
# Issue usage message and quit
#
sub _usage {
    die "usage: $0 -p project_id -c class_dir -o out_dir [-v version_id]"
}

my %cmd_opts;
getopts('p:c:o:v:', \%cmd_opts) or _usage();

_usage() unless defined $cmd_opts{p} and defined $cmd_opts{c} and defined $cmd_opts{o};

my $PID = $cmd_opts{p};
# Directory with class lists
my $CLASS_DIR = abs_path($cmd_opts{c});
-e $CLASS_DIR or die "Directory with class lists does not exist: $CLASS_DIR";
# Output directory for results
my $OUT_DIR = abs_path($cmd_opts{o});
# Optional version id
my $VID = $cmd_opts{v} if defined $cmd_opts{v};
if (defined $VID) {
    $VID =~ /^(\d+)$/ or die "Wrong version id format (\\d+): $VID!";
}

# The mutation operators that should be enabled in the mml file
my @ops =("AOR", "LOR","SOR", "COR", "ROR", "ORU", "LVR", "STD");

system("mkdir -p $OUT_DIR");

my @ids;
# Use specific version id
if (defined $VID) {
    @ids = ($VID);
} else {
    @ids = _get_version_ids();
}

foreach my $vid (@ids) {
    #TODO: Skip id if mml file already exists and the
    # list of classes did not change

    my @classes = _get_class_list($vid);
    my $template = `cat $MAJOR_ROOT/mml/template.mml` or die "Cannot read mml template!";
    my $file = "$OUT_DIR/$vid.mml";

    # Generate mml file by enabling operators for listed classes only
    open(FILE, ">$file") or die "Cannot write mml file ($file): $!";
    # Add operator definitions from template
    print FILE $template;
    # Enable operators for all classes
    foreach my $class (@classes) {
        print FILE "\n// Enable operators for $class\n";
        foreach my $op (@ops) {
            # Skip disabled operators
            next if $template =~ /-$op<"$class">/;
            print FILE "$op<\"$class\">;\n";
        }
    }
    close(FILE);
    my $log = `$MAJOR_ROOT/bin/mmlc $file 2>&1`;
    $? == 0 or die "Cannot compile mml file: $file\n$log";
}

#
# Return list of all classes
#
sub _get_class_list {
    my $id = shift;
    my $list = `cat $CLASS_DIR/$id.src`;
    $? == 0 or die "Cannot read class list for id: $id!";
    return split("\n", $list);
}

#
# Get all version ids for which we have a list of classes
#
sub _get_version_ids {
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
=pod

=head1 SEE ALSO

All valid project_ids are listed in F<Project.pm>

=cut
