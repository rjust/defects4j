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

Constants.pm -- defines/exports all framework-wide constants.

=head1 DESCRIPTION

This module defines all properties for files and directories.
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

# Enable debugging and verbose output
our $DEBUG = 0;

=pod

=head2 Exported environment variables

=over 4

=item C<TZ>

Defects4J sets the timezone to America/Los_Angeles to ensure that all defects
are reproducible and that test suites are generated and executed using the same
timezone setting.

=cut
# TODO: Extract all exported environment variables into a user-visible
# config file.
$ENV{'TZ'} = "America/Los_Angeles";

=pod

=head2 Exported properties (I<default value>)

=over 4

=item C<SCRIPT_DIR>

The directory that contains all scripts and modules (I<parent of this module's directory>)

=cut
our $SCRIPT_DIR = ($ENV{'SCRIPT_DIR'} // abs_path("$dir/../"));

=pod

=item C<CORE_DIR>

The directory that contains all core modules (I<C<SCRIPT_DIR>/core>)

=cut
our $CORE_DIR = ($ENV{'CORE_DIR'} // abs_path("$SCRIPT_DIR/core"));

=pod

=item C<LIB_DIR>

The directory that contains additional libraries (I<C<SCRIPT_DIR>/lib>).

=cut
our $LIB_DIR = ($ENV{'LIB_DIR'} // abs_path("$SCRIPT_DIR/lib"));

=pod

=item C<UTIL_DIR>

The directory that contains util scripts (I<C<SCRIPT_DIR>/util>).

=cut
our $UTIL_DIR = ($ENV{'UTIL_DIR'} // abs_path("$SCRIPT_DIR/util"));

=pod

=item C<BASE_DIR>

The base directory (I<C<SCRIPT_DIR>/..>)

=cut
our $BASE_DIR = ($ENV{'BASE_DIR'} // abs_path("$SCRIPT_DIR/../"));

=pod

=item C<REPO_DIR>

The directory that contains project repositoriy clones (I<C<BASE_DIR>/project_repos>)

=cut
our $REPO_DIR = ($ENV{'REPO_DIR'} // "$BASE_DIR/project_repos");

=pod

=item C<D4J_TMP_DIR>

The temporary root directory, used to checkout a program version (I</tmp>)

=cut
our $D4J_TMP_DIR = ($ENV{'D4J_TMP_DIR'} // "/tmp");

=pod

=item C<MAJOR_ROOT>

The root directory of the Major mutation framework (I<C<BASE_DIR>/major>)

=cut
our $MAJOR_ROOT = ($ENV{'MAJOR_ROOT'} // "$BASE_DIR/major");

=pod

=item C<TESTGEN_LIB_DIR>

The directory of the libraries of the test generation tools (I<C<LIB_DIR>/test_generation/generation>)

=cut
our $TESTGEN_LIB_DIR = ($ENV{'TESTGEN_LIB_DIR'} // "$LIB_DIR/test_generation/generation");

=pod

=item C<D4J_BUILD_FILE>

The top-level (ant) build file (I<C<SCRIPT_DIR>/projects/defects4j.build.xml>)

=back

=cut
our $D4J_BUILD_FILE = ($ENV{'D4J_BUILD_FILE'} or "$SCRIPT_DIR/projects/defects4j.build.xml");

#
# Check whether Defects4J has been properly initialized:
# - Project repos available?
# - Major mutation framework available?
# - External libraries (test generation) available?
#
-e "$REPO_DIR/README"
        or die("Couldn't find project repositories! Did you run 'defects4j/init.sh'?\n\n");
-e "$MAJOR_ROOT/bin/ant"
        or die("Couldn't find Major mutation framework! Did you run 'defects4j/init.sh'?\n\n");
-d "$TESTGEN_LIB_DIR"
        or die("Couldn't find external libraries! Did you run 'defects4j/init.sh'?\n\n");

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

# Filename which stores build properties
our $PROP_FILE       = "defects4j.build.properties";
our $PROP_EXCLUDE    = "d4j.tests.exclude";
our $PROP_INSTRUMENT = "d4j.classes.instrument";
our $PROP_DIR_SRC_CLASSES = "d4j.dir.src.classes";
our $PROP_DIR_SRC_TESTS   = "d4j.dir.src.tests";
our $PROP_CLASSES_MODIFIED= "d4j.classes.modified";
our $PROP_TESTS_TRIGGER   = "d4j.tests.trigger";
our $PROP_PID             = "d4j.project.id";
our $PROP_BID             = "d4j.bug.id";

our $TAG_POST_FIX         = "POST_FIX_REVISION";
our $TAG_POST_FIX_COMP    = "POST_FIX_COMPILABLE";
our $TAG_FIXED            = "FIXED_VERSION";
our $TAG_BUGGY            = "BUGGY_VERSION";
our $TAG_PRE_FIX          = "PRE_FIX_REVISION";

our @EXPORT = qw(
$SCRIPT_DIR
$CORE_DIR
$LIB_DIR
$UTIL_DIR
$BASE_DIR
$MAJOR_ROOT
$TESTGEN_LIB_DIR
$REPO_DIR
$D4J_TMP_DIR

$D4J_BUILD_FILE

$ARG_ERROR
$ABSTRACT_METHOD

$CONFIG
$CONFIG_PID
$CONFIG_VID

$PROP_FILE
$PROP_EXCLUDE
$PROP_INSTRUMENT
$PROP_DIR_SRC_CLASSES
$PROP_DIR_SRC_TESTS
$PROP_CLASSES_MODIFIED
$PROP_TESTS_TRIGGER
$PROP_PID
$PROP_BID

$TAG_POST_FIX
$TAG_POST_FIX_COMP
$TAG_FIXED
$TAG_BUGGY
$TAG_PRE_FIX

$DEBUG
);

