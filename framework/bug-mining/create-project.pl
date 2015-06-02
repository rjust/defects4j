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

create-project.pl -- Configure a new project in Defects4J.

=head1 SYNOPSIS

create-project.pl -p project_id -n project_name

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the new project (e.g., Lang).

=item B<-n C<project_name>>

The (descriptive) name of the new project (e.g., commons-lang).

=back

=head1 DESCRIPTION

Provides templates for the Perl module and wrapper build file for a new project:

=over 4

=item 1) F<framework/core/Project/"project_id".pm>

=item 2) F<framework/build-scripts/"project_id"/"project_id".build.xml>

=back

=cut

use warnings;
use strict;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;

my %cmd_opts;
getopts('p:n:', \%cmd_opts) or pod2usage(1);
my ($PID, $NAME) = ($cmd_opts{p}, $cmd_opts{n});

pod2usage(1) unless defined $PID and defined $NAME;

my $module_template = "$CORE_DIR/Project/template";
my $module_file  = "$CORE_DIR/Project/$PID.pm";

my $build_template = "$SCRIPT_DIR/build-scripts/template";
my $build_file  = "$SCRIPT_DIR/build-scripts/$PID/$PID.build.xml";

-e $module_file and die "Project $PID already exists!";

# Copy module template and set project id and name
open(IN, "<$module_template") or die "Cannot open template file: $!";
open(OUT, ">$module_file") or die "Cannot open module file: $!";
while(<IN>) {
    s/<PID>/$PID/g;
    s/<PROJECT_NAME>/$NAME/g;
    print(OUT $_);
}
close(IN);
close(OUT);

# Create project directory and empty commit-db
system("mkdir $PROJECT_DIR/$PID && touch $PROJECT_DIR/$PID/commit-db");

# Copy wrapper build file template and set project id
system("mkdir $SCRIPT_DIR/build-scripts/$PID");
open(IN, "<$build_template") or die "Cannot open template file: $!";
open(OUT, ">$build_file") or die "Cannot open build file: $!";
while(<IN>) {
    s/<PID>/$PID/g;
    s/<PROJECT_NAME>/$NAME/g;
    print(OUT $_);
}
close(IN);
close(OUT);

=pod

=head1 SEE ALSO

F<Project.pm>

=cut
