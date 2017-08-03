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

DB.pm -- defines/exports all constants and subroutines related to database backends.

=head1 DESCRIPTION

This module defines all database-related properties.
Every property is initialized with a default value, which can be overriden by
setting the corresponding environment variable.

=cut
package DB;

use warnings;
use strict;

use Constants;

use DBI;
use Exporter;

our @ISA = qw(Exporter);

=pod

=head2 Exported properties (I<default value>)

=over 4

=item C<DB_DIR>

The directory of the database storing all results (I<L<BASE_DIR|Constants>/result_db>)

=cut
our $DB_DIR = ($ENV{DB_DIR} or "$BASE_DIR/result_db");

=pod

=item C<TAB_REV_PAIRS>

The name of the database table for the results of analyzing all revision pairs (I<rev_pairs>)

=cut
our $TAB_REV_PAIRS = ($ENV{TAB_REV_PAIRS} or "rev_pairs");

=pod

=item C<TAB_TRIGGER>

The name of the database table for the results of analyzing triggering tests (I<trigger>)

=cut
our $TAB_TRIGGER = ($ENV{TAB_TRIGGER} or "trigger");

=pod

=item C<TAB_BUG_DETECTION>

The name of the database table for the results of running bug detection analysis (I<bug_detection>)

=cut
our $TAB_BUG_DETECTION = ($ENV{TAB_BUG_DETECTION} or "bug_detection");


=pod

=item C<TAB_MUTATION>

The name of the database table for the results of running mutation analysis (I<mutation>)

=cut
our $TAB_MUTATION = ($ENV{TAB_MUTATION} or "mutation");

=pod

=item C<TAB_COVERAGE>

The name of the database table for the results of running coverage analysis (I<coverage>)

=cut
our $TAB_COVERAGE = ($ENV{TAB_COVERAGE} or "coverage");

=pod

=item C<TAB_CODE_EVOLUTION>

The name of the database table for the results of running code evolution analysis (I<code_evolution>)

=cut
our $TAB_CODE_EVOLUTION = ($ENV{TAB_CODE_EVOLUTION} or "code_evolution");

=pod

=item C<TAB_REVIEW>

=back

The name of the database table for the results of patch review (I<review>)

=cut
our $TAB_REVIEW = ($ENV{TAB_REVIEW} or "review");

=pod

=item C<TAB_FIX>

=back

The name of the database table for the results of fixing automatically generated test cases (I<fix>)

=cut
our $TAB_FIX = ($ENV{TAB_FIX} or "fix");

# Common columns for all tables
our $PROJECT       = "project_id";
our $ID            = "version_id";

# Additional columns of TAB_REV_PAIRS
our $DIFF_SRC      = "diff_size_src";
our $DIFF_TEST     = "diff_size_test";
our $COMP_V2       = "compile_v2";
our $COMP_T2V2     = "compile_t2v2";
our $FAIL_T2V2     = "num_fail_t2v2";
our $COMP_V1       = "compile_v1";
our $COMP_T2V1     = "compile_t2v1";
our $MIN_SRC       = "minimized_src_patch";
our $REVIEW_TESTS  = "reviewed_tests_t2v2";

# Additional columns of TAB_TRIGGER
our $FAIL_V2       = "num_fail_t2v2";
our $FAIL_C_V1     = "num_fail_classes_t2v1";
our $FAIL_M_V1     = "num_fail_methods_t2v1";
our $FAIL_ISO_V1   = "fail_iso_t2v1";
our $PASS_ISO_V2   = "pass_iso_t2v2";

# Additional columns of TAB_BUG_DETECTION, TAB_MUTATION, and TAB_FIX
our $TEST_SUITE = "test_suite_source";
our $TEST_ID    = "test_id";

# Additional columns of TAB_BUG_DETECTION and TAB_CODE_EVOLUTION
our $TEST_CLASS = "test_classification";
our $NUM_TRIGGER= "num_trigger";

# Additional columns of TAB_MUTATION
our $MUT_GEN    = "mut_generated";
our $MUT_EXCL   = "mut_excluded";
our $MUT_COV    = "mut_covered";
our $MUT_KILL   = "mut_killed";

# Additional columns of TAB_COVERAGE
our $LINES_TOTAL      = "lines_total";
our $LINES_COVERED    = "lines_covered";
our $BRANCHES_TOTAL   = "branches_total";
our $BRANCHES_COVERED = "branches_covered";

# Additional columns of TAB_CODE_EVOLUTION
our $NUM_COMMITS      = "num_commits";
our $PASSED_COMMITS   = "passed_commits";

# Additional columns of TAB_FIX
our $NUM_UNCOMPILABLE_TESTS        = "num_uncompilable_tests";
our $NUM_UNCOMPILABLE_TEST_CLASSES = "num_uncompilable_test_classes";
our $NUM_FAILING_TESTS             = "num_failing_tests";

# Table definitions
my %tables = (
# TAB_REV_PAIRS
$TAB_REV_PAIRS => [$PROJECT, $ID, $DIFF_SRC, $DIFF_TEST, $COMP_V2, $COMP_T2V2, $FAIL_T2V2, $COMP_V1, $COMP_T2V1, $MIN_SRC, $REVIEW_TESTS],
# Table TAB_TRIGGER
$TAB_TRIGGER => [$PROJECT, $ID, $FAIL_V2, $FAIL_C_V1, $FAIL_M_V1, $PASS_ISO_V2, $FAIL_ISO_V1],
# Table TAB_BUG_DETECTION
$TAB_BUG_DETECTION => [$PROJECT, $ID, $TEST_SUITE, $TEST_ID, $TEST_CLASS, $NUM_TRIGGER],
# Table TAB_MUTATION
$TAB_MUTATION => [$PROJECT, $ID, $TEST_SUITE, $TEST_ID, $MUT_GEN, $MUT_EXCL, $MUT_COV, $MUT_KILL],
# Table TAB_COVERAGE
$TAB_COVERAGE => [$PROJECT, $ID, $TEST_SUITE, $TEST_ID, $LINES_TOTAL, $LINES_COVERED, $BRANCHES_TOTAL, $BRANCHES_COVERED],
# Table TAB_CODE_EVOLUTION
$TAB_CODE_EVOLUTION => [$PROJECT, $ID, $TEST_SUITE, $TEST_ID, $NUM_COMMITS, $PASSED_COMMITS, $TEST_CLASS, $NUM_TRIGGER],
# Table TAB_FIX
$TAB_FIX => [$PROJECT, $ID, $TEST_SUITE, $TEST_ID, $NUM_UNCOMPILABLE_TESTS, $NUM_UNCOMPILABLE_TEST_CLASSES, $NUM_FAILING_TESTS],
);


## number of columns making the primary key in each table
our %PRIMARY_KEYS = (
    $TAB_REV_PAIRS => 2,
    $TAB_TRIGGER => 2,
    $TAB_BUG_DETECTION => 4,
    $TAB_MUTATION => 4,
    $TAB_COVERAGE => 4,
    $TAB_CODE_EVOLUTION => 4,
    $TAB_FIX => 4,
);

our @EXPORT = qw(
$DB_DIR
$TAB_REV_PAIRS
$TAB_TRIGGER
$TAB_BUG_DETECTION
$TAB_MUTATION
$TAB_REVIEW
$TAB_COVERAGE
$TAB_CODE_EVOLUTION
$TAB_FIX

$PROJECT
$ID
$DIFF_SRC
$DIFF_TEST
$COMP_V2
$COMP_T2V2
$FAIL_T2V2
$COMP_V1
$COMP_T2V1
$MIN_SRC
$REVIEW_TESTS
$FAIL_V2
$FAIL_C_V1
$FAIL_M_V1
$FAIL_ISO_V1
$PASS_ISO_V2
$TEST_SUITE
$TEST_ID
$TEST_CLASS
$NUM_TRIGGER
$MUT_GEN
$MUT_EXCL
$MUT_COV
$MUT_KILL
$LINES_TOTAL
$LINES_COVERED
$BRANCHES_TOTAL
$BRANCHES_COVERED
$NUM_COMMITS
$PASSED_COMMITS
$NUM_UNCOMPILABLE_TESTS
$NUM_UNCOMPILABLE_TEST_CLASSES
$NUM_FAILING_TESTS

%PRIMARY_KEYS
);
=pod

=head2 Static subroutines:

  get_db_handle(table [, db_dir])

Connect to database and return database handle -- this subroutine will initialize
the database and the requested C<table> if necessary.

=cut
sub get_db_handle {
    my $table = shift @_ // die $ARG_ERROR;
    my $db_dir = shift @_ // $DB_DIR;
    my $dbh;

    defined $tables{$table} or die "Unknown table: $table!";

    # Create database if necessary
    if (!-e $db_dir) {
        `mkdir -p $db_dir`;
    }

    $dbh = DBI->connect ("dbi:CSV:f_dir=$db_dir") or die "Cannot connect: $DBI::errstr";

    # Create table if necessary
    unless (-e "$db_dir/$table") {
        my @cols;
        # Add data type to column name
        foreach my $col (@{$tables{$table}}) {
            #TODO Add support for correct data types
            push(@cols, "$col CHAR");
        }
        $dbh->do("CREATE TABLE $table (" . join(",", @cols) . ")");
    }
    return $dbh;
}

=pod

  get_tab_columns(table)

Returns a list of column names for C<table> or C<undef> if this table does not exist.

=cut
sub get_tab_columns {
    my $table = shift;
    return @{$tables{$table}};
}
