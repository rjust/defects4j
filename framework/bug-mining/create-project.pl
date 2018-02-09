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

create-project.pl -- Configure a new project for Defects4J.

=head1 SYNOPSIS

create-project.pl -p project_id -n project_name -w work_dir

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the new project (e.g., Lang).

=item B<-n C<project_name>>

The (descriptive) name of the new project (e.g., commons-lang).

=item B<-w C<work_dir>>

The working directory for the bug-mining process.

=back

=head1 DESCRIPTION

Provides templates for the Perl module and wrapper build file for a new project:

=over 4

=item 1) F<"work_dir"/framework/core/Project/"project_id".pm>

=item 2) F<"work_dir"/framework/projects/"project_id"/"project_id".build.xml>

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
getopts('p:n:w:', \%cmd_opts) or pod2usage(1);
pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{n} and defined $cmd_opts{w};

my ($PID, $NAME, $WORK_DIR) = ($cmd_opts{p}, $cmd_opts{n}, $cmd_opts{w});

# TODO: Copy existing project module and build file to working directory
-e "$CORE_DIR/Project/$PID.pm" and die "Project $PID already exists!";

my $module_template = "$CORE_DIR/Project/template";
my $build_template  = "$SCRIPT_DIR/projects/template.build.xml";

my $module_file  = "$WORK_DIR/framework/core/Project/$PID.pm";
my $build_file   = "$WORK_DIR/framework/projects/$PID/$PID.build.xml";

# Initialize working directory and create empty commit-db
my $project_dir = "$WORK_DIR/framework/projects/$PID";

# Directories for meta data
my $PATCH_DIR   = "$project_dir/patches";
my $FAILING_DIR = "$project_dir/failing_tests";
my $TRIGGER_DIR = "$project_dir/trigger_tests";
my $MOD_CLASSES = "$project_dir/modified_classes";
# Directory for the perl module
my $core_dir = $WORK_DIR/framework/core/Project

system("mkdir -p $core_dir $PATCH_DIR $FAILING_DIR $TRIGGER_DIR $MOD_CLASSES");
system("touch $project_dir/commit-db");

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

# Copy wrapper build file template and set project id
open(IN, "<$build_template") or die "Cannot open template file: $!";
open(OUT, ">$build_file") or die "Cannot open build file: $!";
while(<IN>) {
    s/<PID>/$PID/g;
    s/<PROJECT_NAME>/$NAME/g;
    print(OUT $_);
}
close(IN);
close(OUT);
