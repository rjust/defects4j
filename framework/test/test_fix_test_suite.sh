#!/usr/bin/env bash
################################################################################
#
# This script tests the util/fix_test_suite.pl script.
#
################################################################################

HERE=$(cd `dirname $0` && pwd)

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

pid="Math" # any pid-bid should work
bid="1b"

# Directory for test suites
suites_dir="$TMP_DIR/test_suites_dir"

# ------------------------------------------------------------- Common functions

_check_output() {
  local USAGE="Usage: _check_output <actual> <expected>"
  if [ "$#" != 2 ]; then
    echo "$USAGE" >&2
    return 1
  fi

  local actual="$1"
  local expected="$2"

  cmp --silent "$expected" "$actual" || die "'$actual' is not equal to '$expected'!"
  return 0
}

_create_tar_bz2_file() {
  local USAGE="Usage: _create_tar_bz2_file <pid> <bid> <suites_dir>"
  if [ "$#" != 3 ]; then
    echo "$USAGE" >&2
    return 1
  fi

  local pid="$1"
  local bid="$2"
  local suites_dir="$3"

  # Create a .tar.bz2 file with all test suites
  pushd . > /dev/null 2>&1
  cd "$HERE/resources/input"
    tar_bz2_file="$suites_dir/$pid-$bid-test.0.tar.bz2"
    tar -jcvf "$tar_bz2_file" \
      foo/bar/FailingTests.java \
      foo/bar/InvalidImport.java \
      foo/bar/UnitTestsWithCompilationIssues.java \
      foo/bar/ValidTestClass.java \
      foo/bar/LineCommentsWithWhitespaces.java \
      foo/bar/InvalidCharacters.java || return 1
  popd > /dev/null 2>&1

  return 0
}

# ------------------------------------------------------------------- Test Cases

_test_deletion_of_test_classes_and_test_cases() {
  rm -rf "$suites_dir"; mkdir -p "$suites_dir"

  _create_tar_bz2_file "$pid" "$bid" "$suites_dir" || die "Was not possible to create a .tar.bz2 file with all test suites!"

  # Fix test suites
  fix_test_suite.pl -p "$pid" -d "$suites_dir" -v "$bid" || die "Script 'fix_test_suite.pl' has failed!"

  tar -jxvf "$tar_bz2_file" -C "$suites_dir"

  # Check output of 'fix_test_suite.pl' script

  _check_output \
    "$HERE/resources/output/foo/bar/FailingTests.java" \
    "$suites_dir/foo/bar/FailingTests.java"

  _check_output \
    "$HERE/resources/output/foo/bar/FailingTests.java.bak" \
    "$suites_dir/foo/bar/FailingTests.java.bak"

  _check_output \
    "$HERE/resources/output/foo/bar/InvalidImport.java.broken" \
    "$suites_dir/foo/bar/InvalidImport.java.broken"

  _check_output \
    "$HERE/resources/output/foo/bar/UnitTestsWithCompilationIssues.java" \
    "$suites_dir/foo/bar/UnitTestsWithCompilationIssues.java"

  _check_output \
    "$HERE/resources/output/foo/bar/UnitTestsWithCompilationIssues.java.bak" \
    "$suites_dir/foo/bar/UnitTestsWithCompilationIssues.java.bak"

  _check_output \
    "$HERE/resources/output/foo/bar/ValidTestClass.java" \
    "$suites_dir/foo/bar/ValidTestClass.java"

  _check_output \
    "$HERE/resources/output/foo/bar/LineCommentsWithWhitespaces.java" \
    "$suites_dir/foo/bar/LineCommentsWithWhitespaces.java"

  _check_output \
    "$HERE/resources/output/foo/bar/InvalidCharacters.java" \
    "$suites_dir/foo/bar/InvalidCharacters.java"

  return 0
}

_test_L_option_enabled() {
    # Are DBI and DBD:CSV available?
    if ! perl -e 'use DBI; use DBD::CSV;' 2>/dev/null; then
        die "Please make sure perl modules 'DBI' and 'DBD:CSV' are installed."
    fi

    rm -rf "$suites_dir"; mkdir -p "$suites_dir"

    _create_tar_bz2_file "$pid" "$bid" "$suites_dir" || die "Was not possible to create a .tar.bz2 file with all test suites!"

    # enable DBI by calling the script with -L option
    fix_test_suite.pl -p "$pid" -d "$suites_dir" -v "$bid" -L || die "Script 'fix_test_suite.pl' has failed!"

    fix_db="$suites_dir/fix"
    [ -s "$fix_db" ] || die "Database file 'fix' doesn't exist or is empty!"

    num_rows=$(cat "$fix_db" | wc -l)
    [ "$num_rows" -eq 2 ] || die "Database file 'fix' does not have 2 rows!"

    # Columns of 'fix' database file:
    # project_id,version_id,test_suite_source,test_id,num_uncompilable_tests,num_uncompilable_test_classes,num_failing_tests
    expected="$pid,$bid,test,1,2,1,5"

    # Convert DOS (\r\n) to Unix (\n) line ending and check data of last row
    actual=$(tr -d '\r' < "$fix_db" | tail -n1)
    [ "$actual" == "$expected" ] || die "Unexpected result (expected: '$expected'; actual: '$actual')!"

    return 0
}

_test_deletion_of_test_classes_and_test_cases || die "Test '_test_deletion_of_test_classes_and_test_cases' has failed!"
_test_L_option_enabled || die "Test '_test_L_option_enabled' has failed!"

# Clean up
rm -rf "$suites_dir"
