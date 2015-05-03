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

Constants.pm -- Defines/exports all project-wide properties.

=head1 DESCRIPTION

This module provides all properties for files and directories.
Every property is initialized with a default value, which can be overriden by
setting the corresponding environment variable.

=cut
package Constants;

use 5.010;
use warnings;
use strict;

use File::Basename;
use Cwd qw(abs_path);
use Exporter;

our @ISA = qw(Exporter);

my $dir = dirname(abs_path(__FILE__));

=pod

=head3 Exported properties (I<default value>):

=over 4

=item B<SCRIPT_DIR>

The directory that contains all scripts (I<directory of this module>)

=cut
our $SCRIPT_DIR = ($ENV{'SCRIPT_DIR'} or abs_path("$dir/../"));

=pod

=item B<CORE_DIR>

The directory that contains all core modules (I<$SCRIPT_DIR/core>)

=cut
our $CORE_DIR = ($ENV{'CORE_DIR'} or abs_path("$SCRIPT_DIR/core"));

=pod

=item B<LIB_DIR>

The directory that contains any extra perl modules or additional libraries we reference (I<$SCRIPT_DIR/lib>).

=cut
our $LIB_DIR = ($ENV{'LIB_DIR'} or abs_path("$SCRIPT_DIR/lib"));

=pod

=item B<UTIL_DIR>

The directory that contains util scripts (I<$SCRIPT_DIR/util>).

=cut
our $UTIL_DIR = ($ENV{'UTIL_DIR'} or abs_path("$SCRIPT_DIR/util"));

=pod

=item B<BASE_DIR>

The base directory (I<$SCRIPT_DIR/..>)

=cut
our $BASE_DIR = ($ENV{'BASE_DIR'} or abs_path("$SCRIPT_DIR/../"));

=pod

=item B<REPO_DIR>

The directory that contains project repositoriy clones (I<$BASE_DIR/project_repos>)

=cut
our $REPO_DIR = ($ENV{'REPO_DIR'} or "$BASE_DIR/project_repos");

=pod

=item B<MAJOR_ROOT>

The root directory of the Major framework (I<$BASE_DIR/major>)

=back

=cut
our $MAJOR_ROOT = ($ENV{'MAJOR_ROOT'} or "$BASE_DIR/major");

# Add script and core directory to @INC
unshift(@INC, $CORE_DIR);
unshift(@INC, $SCRIPT_DIR);
unshift(@INC, $LIB_DIR);
# Prepend Major's executables to the PATH
$ENV{PATH}="$MAJOR_ROOT/bin:$ENV{PATH}";
# set name of mml file that provides definitions of used mutation operators
$ENV{MML}="$MAJOR_ROOT/mml/all_mutants.mml.bin" unless defined $ENV{'MML'};

# Constant strings used for errors
our $ARG_ERROR       = "Invalid number of arguments!";
our $ABSTRACT_METHOD = "Abstract method called!";

# Filename which stores information about the checked-out revision
our $CONFIG = ".defects4j.config";
our $CONFIG_PID = "pid";
our $CONFIG_VID = "vid";

our $DEBUG = 0;

our @EXPORT = qw(
$SCRIPT_DIR
$CORE_DIR
$LIB_DIR
$UTIL_DIR
$BASE_DIR
$MAJOR_ROOT
$REPO_DIR

$ARG_ERROR
$ABSTRACT_METHOD

$CONFIG
$CONFIG_PID
$CONFIG_VID

$DEBUG
);

