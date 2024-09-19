#-------------------------------------------------------------------------------
# Copyright (c) 2014-2024 René Just, Darioush Jalali, and Defects4J contributors.
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

use 5.012;
use warnings;
use strict;

use File::Basename;
use Cwd qw(abs_path);
use Exporter;

our @ISA = qw(Exporter);

my $dir = dirname(abs_path(__FILE__));

# Enable debugging and verbose output
our $DEBUG = $ENV{'D4J_DEBUG'} // 0;

=pod

=head2 Exported environment variables

=over 4

=item C<TZ>

Defects4J sets the timezone to America/Los_Angeles to ensure that all defects
are reproducible and that test suites are generated and executed using the same
timezone setting.

=back

=cut

# TODO: Extract all exported environment variables into a user-visible
# config file.
$ENV{'TZ'} = "America/Los_Angeles";

=pod

=head2 Exported properties

This module exports the following properties. The default value for each
property appears in parentheses (I<default value>).

The default value for each property can be overridden by setting and exporting
an evironment variable with the same name, prior to calling Defects4J.
For example, the default value for C<PROJECTS_DIR> can be overridden with:
C<export PROJECTS_DIR=my_project_directory>.

=over 4

=item C<SCRIPT_DIR>

The directory that contains all scripts and modules (I<parent of this module's directory>)

=cut

our $SCRIPT_DIR = ($ENV{'SCRIPT_DIR'} // abs_path("$dir/../"));

=item C<PROJECTS_DIR>

The directory that contains all project metadata (I<C<SCRIPT_DIR>/projects>)

=cut

our $PROJECTS_DIR = ($ENV{'PROJECTS_DIR'} // abs_path("$SCRIPT_DIR/projects"));

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

=item C<TESTGEN_BIN_DIR>

The directory of the wrapper scripts of the test generation tools (I<C<LIB_DIR>/test_generation/bin>)

=cut

our $TESTGEN_BIN_DIR = ($ENV{'TESTGEN_BIN_DIR'} // "$LIB_DIR/test_generation/bin");

=pod

=item C<BUILD_SYSTEMS_LIB_DIR>

The directory of the libraries of the build system tools (I<C<LIB_DIR>/build_systems>)

=cut

our $BUILD_SYSTEMS_LIB_DIR = ($ENV{'BUILD_SYSTEMS_LIB_DIR'} // "$LIB_DIR/build_systems");

=pod

=item C<D4J_BUILD_FILE>

The top-level (ant) build file (I<C<SCRIPT_DIR>/projects/defects4j.build.xml>)

=cut

our $D4J_BUILD_FILE = ($ENV{'D4J_BUILD_FILE'} // "$SCRIPT_DIR/projects/defects4j.build.xml");

=pod

=item C<GRADLE_LOCAL_HOME_DIR>

The directory name of the local gradle repository (I<.gradle_local_home>).

=back

=cut

our $GRADLE_LOCAL_HOME_DIR = ($ENV{'GRADLE_LOCAL_HOME_DIR'} // ".gradle_local_home");

#
# Check if we have the correct version of Java
#
# Run the 'java -version' command and capture its output
my $java_version_output = `java -version 2>&1`;

# Extract the imajor version number using regular expressions
if ($java_version_output =~ 'version "?(?:1\.)?(\K\d+)') {
    if ($1 != 11) {
        die ("Java 11 is required!\n\n");
    }
} else {
    die ("Failed to parse Java version! Is Java installed/on the execution path?\n\n");
}

#
# Check whether Defects4J has been properly initialized:
# - Project repos available?
# - Major mutation framework available?
# - External libraries (test generation) available?
#
_repos_available()
        or die("Couldn't find up-to-date project repositories! Did you (re)run 'defects4j/init.sh'?\n\n");

-e "$MAJOR_ROOT/bin/ant"
        or die("Couldn't find Major mutation framework! Did you (re)run 'defects4j/init.sh'?\n\n");

-d "$TESTGEN_LIB_DIR"
        or die("Couldn't find test generation tools! Did you (re)run 'defects4j/init.sh'?\n\n");

-d "$BUILD_SYSTEMS_LIB_DIR"
        or die("Couldn't find build system tools! Did you (re)run 'defects4j/init.sh'?\n\n");

-d "$BUILD_SYSTEMS_LIB_DIR/gradle/dists"
        or die("Couldn't find gradle distributions! Did you (re)run 'defects4j/init.sh'?\n\n");

-d "$BUILD_SYSTEMS_LIB_DIR/gradle/deps"
        or die("Couldn't find gradle dependencies! Did you (re)run 'defects4j/init.sh'?\n\n");

sub _repos_available {
    -e "$REPO_DIR/README" or return 0;
    open(IN, "<$REPO_DIR/README") or return 0;
    my $line = <IN>;
    close(IN);
    $line =~ /Defects4J version 3/ or return 0;
}

# Add script and core directory to @INC
unshift(@INC, $CORE_DIR);
unshift(@INC, $SCRIPT_DIR);
unshift(@INC, $LIB_DIR);
# Append Major's executables to the PATH -> ant may not be installed by default
$ENV{PATH}="$MAJOR_ROOT/bin:$ENV{PATH}";

# Constant strings used for errors
our $ARG_ERROR       = "Invalid number of arguments!";
our $ABSTRACT_METHOD = "Abstract method called!";

# Filename which stores information about the checked-out revision
our $CONFIG = ".defects4j.config";
our $CONFIG_PID = "pid";
our $CONFIG_VID = "vid";

# Filename which stores build properties
our $PROP_FILE = "defects4j.build.properties";

# Keys of stored properties
our $PROP_EXCLUDE         = "d4j.tests.exclude";
our $PROP_INSTRUMENT      = "d4j.classes.instrument";
our $PROP_MUTATE          = "d4j.classes.mutate";
our $PROP_MUT_OPS         = "d4j.major.mutops";
our $PROP_DIR_SRC_CLASSES = "d4j.dir.src.classes";
our $PROP_DIR_SRC_TESTS   = "d4j.dir.src.tests";
our $PROP_CLASSES_MODIFIED= "d4j.classes.modified";
our $PROP_CLASSES_RELEVANT= "d4j.classes.relevant";
our $PROP_TESTS_TRIGGER   = "d4j.tests.trigger";
our $PROP_PID             = "d4j.project.id";
our $PROP_BID             = "d4j.bug.id";

# Tags for local git repo in working directory
our $TAG_POST_FIX         = "POST_FIX_REVISION";
our $TAG_POST_FIX_COMP    = "POST_FIX_COMPILABLE";
our $TAG_FIXED            = "FIXED_VERSION";
our $TAG_BUGGY            = "BUGGY_VERSION";
our $TAG_PRE_FIX          = "PRE_FIX_REVISION";

# Filename for directory layout csv
our $LAYOUT_FILE = "dir-layout.csv";

# Filenames for bugs csv files
our $BUGS_CSV_ACTIVE = "active-bugs.csv";
our $BUGS_CSV_DEPRECATED = "deprecated-bugs.csv";

# Columns in active-bugs and deprecated-bugs csvs
our $BUGS_CSV_BUGID = "bug.id";
our $BUGS_CSV_COMMIT_BUGGY = "revision.id.buggy";
our $BUGS_CSV_COMMIT_FIXED = "revision.id.fixed";
our $BUGS_CSV_ISSUE_ID = "report.id";
our $BUGS_CSV_ISSUE_URL = "report.url";
our $BUGS_CSV_DEPRECATED_WHEN = "deprecated.version";
our $BUGS_CSV_DEPRECATED_WHY = "deprecated.reason";

# Reasons for deprecation
our $DEPRECATED_DUPLICATE = "Duplicate";
our $DEPRECATED_JVM8_REPRO = "JVM8.Not.Reproducible";
our $DEPRECATED_JVM8_COMPILE = "JVM8.Does.Not.Compile";

# Additional metadata fields that can be queried by d4j-query
our $METADATA_PROJECT_ID = "project.id";
our $METADATA_PROJECT_NAME = "project.name";
our $METADATA_BUILD_FILE = "project.build.file";
our $METADATA_VCS = "project.vcs";
our $METADATA_REPOSITORY = "project.repository";
our $METADATA_COMMIT_DB = "project.bugs.csv";
our $METADATA_LOADED_CLASSES_SRC = "classes.relevant.src";
our $METADATA_LOADED_CLASSES_TEST = "classes.relevant.test";
our $METADATA_MODIFIED_CLASSES = "classes.modified";
our $METADATA_RELEVANT_TESTS = "tests.relevant";
our $METADATA_TRIGGER_TESTS = "tests.trigger"; 
our $METADATA_TRIGGER_CAUSE = "tests.trigger.cause";
our $METADATA_DATE_BUGGY = "revision.date.buggy";
our $METADATA_DATE_FIXED = "revision.date.fixed";

# Filenames for test results
our $FILE_ALL_TESTS     = "all_tests";
our $FILE_FAILING_TESTS = "failing_tests";

our @EXPORT = qw(
$SCRIPT_DIR
$PROJECTS_DIR
$CORE_DIR
$LIB_DIR
$UTIL_DIR
$BASE_DIR
$MAJOR_ROOT
$TESTGEN_BIN_DIR
$TESTGEN_LIB_DIR
$BUILD_SYSTEMS_LIB_DIR
$REPO_DIR
$D4J_TMP_DIR

$D4J_BUILD_FILE

$GRADLE_LOCAL_HOME_DIR

$ARG_ERROR
$ABSTRACT_METHOD

$CONFIG
$CONFIG_PID
$CONFIG_VID

$PROP_FILE
$PROP_EXCLUDE
$PROP_INSTRUMENT
$PROP_MUTATE
$PROP_MUT_OPS
$PROP_DIR_SRC_CLASSES
$PROP_DIR_SRC_TESTS
$PROP_CLASSES_MODIFIED
$PROP_CLASSES_RELEVANT
$PROP_TESTS_TRIGGER
$PROP_PID
$PROP_BID

$TAG_POST_FIX
$TAG_POST_FIX_COMP
$TAG_FIXED
$TAG_BUGGY
$TAG_PRE_FIX

$LAYOUT_FILE

$BUGS_CSV_ACTIVE
$BUGS_CSV_DEPRECATED

$BUGS_CSV_BUGID
$BUGS_CSV_COMMIT_BUGGY
$BUGS_CSV_COMMIT_FIXED
$BUGS_CSV_ISSUE_ID
$BUGS_CSV_ISSUE_URL
$BUGS_CSV_DEPRECATED_WHEN
$BUGS_CSV_DEPRECATED_WHY

$DEPRECATED_DUPLICATE
$DEPRECATED_JVM8_REPRO
$DEPRECATED_JVM8_COMPILE

$METADATA_LOADED_CLASSES_SRC
$METADATA_LOADED_CLASSES_TEST
$METADATA_MODIFIED_CLASSES
$METADATA_RELEVANT_TESTS
$METADATA_TRIGGER_TESTS
$METADATA_TRIGGER_CAUSE
$METADATA_PROJECT_ID
$METADATA_PROJECT_NAME
$METADATA_BUILD_FILE
$METADATA_VCS
$METADATA_REPOSITORY
$METADATA_COMMIT_DB
$METADATA_DATE_BUGGY
$METADATA_DATE_FIXED

$FILE_ALL_TESTS
$FILE_FAILING_TESTS

$DEBUG
);

