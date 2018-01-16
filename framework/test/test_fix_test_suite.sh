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

_check_fix_db() {
  local USAGE="Usage: _check_fix_db <fix_db_file> <expected_db_data>"
  if [ "$#" != 2 ]; then
    echo "$USAGE" >&2
    return 1
  fi

  local fix_db_file="$1"
  local expected_db_data="$2"

  [ -s "$fix_db_file" ] || die "Database file 'fix' doesn't exist or is empty!"

  local num_rows=$(cat "$fix_db_file" | wc -l)
  [ "$num_rows" -eq 2 ] || die "Database file 'fix' does not have 2 rows!"

  # Convert DOS (\r\n) to Unix (\n) line ending and check data of last row
  local actual_db_data=$(tr -d '\r' < "$fix_db_file" | tail -n1)
  [ "$actual_db_data" == "$expected_db_data" ] || die "Unexpected result (expected: '$expected_db_data'; actual: '$actual_db_data')!"

  return 0
}

_create_tar_bz2_file() {
  local USAGE="Usage: _create_tar_bz2_file <pid> <bid> <input_files <suites_dir>"
  if [ "$#" != 4 ]; then
    echo "$USAGE" >&2
    return 1
  fi

  local pid="$1"
  local bid="$2"
  local input_files="$3"
  local suites_dir="$4"

  # Create a .tar.bz2 file with all test suites
  pushd . > /dev/null 2>&1
  cd "$HERE/resources/input"
    tar_bz2_file="$suites_dir/$pid-$bid-test.0.tar.bz2"
    tar -jcvf "$tar_bz2_file" "$input_files"  || return 1
  popd > /dev/null 2>&1

  return 0
}

# ------------------------------------------------------------------- Test Cases

run_fix_test_suite_test_case() {
  local USAGE="Usage: run_fix_test_suite_test_case <pid> <bid> <input_files> <output_files> <suites_dir> [extra options]"
  if [ "$#" -lt 5 ] && [ "$#" -gt 6 ]; then
    echo "$USAGE" >&2
    return 1
  fi

  local pid="$1"
  local bid="$2"
  local input_files="$3"
  local output_files="$4"
  local suites_dir="$5"
  local fix_test_suite_options="$6"

  rm -rf "$suites_dir"; mkdir -p "$suites_dir"

  _create_tar_bz2_file "$pid" "$bid" "$input_files" "$suites_dir" || die "Was not possible to create a .tar.bz2 file with all test suites!"

  # Fix test suites
  fix_test_suite.pl -p "$pid" -d "$suites_dir" -v "$bid" "$fix_test_suite_options" || die "Script 'fix_test_suite.pl' has failed!"

  tar -jxvf "$tar_bz2_file" -C "$suites_dir"

  # Check output of 'fix_test_suite.pl' script
  for output_file in $(echo "$output_files" | tr ' ' '\n'); do
    _check_output \
      "$HERE/resources/output/$output_file" \
      "$suites_dir/$output_file"
  done

  return 0
}

test_FailingTests() {
  local suites_dir="$TMP_DIR/test_FailingTests"

  local pid="Math"
  local bid="1b"

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/FailingTests.java" "foo/bar/FailingTests.java foo/bar/FailingTests.java.bak" \
    "$suites_dir" || return 1

  if ! perl -e 'use DBI; use DBD::CSV;' 2>/dev/null; then
    echo "Warning: Please make sure perl modules 'DBI' and 'DBD:CSV' are installed."
    return 0
  fi

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/FailingTests.java" "foo/bar/FailingTests.java foo/bar/FailingTests.java.bak" \
    "$suites_dir" \
    "-L" || return 1

  # Columns of 'fix' database file:
  # project_id,version_id,test_suite_source,test_id,num_uncompilable_tests,num_uncompilable_test_classes,num_failing_tests
  local expected_db_data="$pid,$bid,test,1,0,0,3"
  _check_fix_db "$suites_dir/fix" "$expected_db_data" || return 1

  # Clean up
  rm -rf "$suites_dir"

  return 0
}

test_InvalidImport() {
  local suites_dir="$TMP_DIR/test_InvalidImport"

  local pid="Math"
  local bid="1b"

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/InvalidImport.java" "foo/bar/InvalidImport.java.broken" \
    "$suites_dir" || return 1

  if ! perl -e 'use DBI; use DBD::CSV;' 2>/dev/null; then
    echo "Warning: Please make sure perl modules 'DBI' and 'DBD:CSV' are installed."
    return 0
  fi

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/InvalidImport.java" "foo/bar/InvalidImport.java.broken" \
    "$suites_dir" \
    "-L" || return 1

  # Columns of 'fix' database file:
  # project_id,version_id,test_suite_source,test_id,num_uncompilable_tests,num_uncompilable_test_classes,num_failing_tests
  local expected_db_data="$pid,$bid,test,1,0,1,0"
  _check_fix_db "$suites_dir/fix" "$expected_db_data" || return 1

  # Clean up
  rm -rf "$suites_dir"

  return 0
}

test_UnitTestsWithCompilationIssues() {
  local suites_dir="$TMP_DIR/test_UnitTestsWithCompilationIssues"

  local pid="Math"
  local bid="1b"

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/UnitTestsWithCompilationIssues.java" "foo/bar/UnitTestsWithCompilationIssues.java foo/bar/UnitTestsWithCompilationIssues.java.bak" \
    "$suites_dir" || return 1

  if ! perl -e 'use DBI; use DBD::CSV;' 2>/dev/null; then
    echo "Warning: Please make sure perl modules 'DBI' and 'DBD:CSV' are installed."
    return 0
  fi

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/UnitTestsWithCompilationIssues.java" "foo/bar/UnitTestsWithCompilationIssues.java foo/bar/UnitTestsWithCompilationIssues.java.bak" \
    "$suites_dir" \
    "-L" || return 1

  # Columns of 'fix' database file:
  # project_id,version_id,test_suite_source,test_id,num_uncompilable_tests,num_uncompilable_test_classes,num_failing_tests
  local expected_db_data="$pid,$bid,test,1,2,0,0"
  _check_fix_db "$suites_dir/fix" "$expected_db_data" || return 1

  # Clean up
  rm -rf "$suites_dir"

  return 0
}

test_ValidTestClass() {
  local suites_dir="$TMP_DIR/test_ValidTestClass"

  local pid="Math"
  local bid="1b"

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/ValidTestClass.java" "foo/bar/ValidTestClass.java" \
    "$suites_dir" || return 1

  if ! perl -e 'use DBI; use DBD::CSV;' 2>/dev/null; then
    echo "Warning: Please make sure perl modules 'DBI' and 'DBD:CSV' are installed."
    return 0
  fi

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/ValidTestClass.java" "foo/bar/ValidTestClass.java" \
    "$suites_dir" \
    "-L" || return 1

  # Columns of 'fix' database file:
  # project_id,version_id,test_suite_source,test_id,num_uncompilable_tests,num_uncompilable_test_classes,num_failing_tests
  local expected_db_data="$pid,$bid,test,1,0,0,0"
  _check_fix_db "$suites_dir/fix" "$expected_db_data" || return 1

  # Clean up
  rm -rf "$suites_dir"

  return 0
}

test_LineCommentsWithWhitespaces() { # Issue 96
  local suites_dir="$TMP_DIR/test_LineCommentsWithWhitespaces"

  local pid="Math"
  local bid="1b"

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/LineCommentsWithWhitespaces.java" "foo/bar/LineCommentsWithWhitespaces.java" \
    "$suites_dir" || return 1

  if ! perl -e 'use DBI; use DBD::CSV;' 2>/dev/null; then
    echo "Warning: Please make sure perl modules 'DBI' and 'DBD:CSV' are installed."
    return 0
  fi

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/LineCommentsWithWhitespaces.java" "foo/bar/LineCommentsWithWhitespaces.java" \
    "$suites_dir" \
    "-L" || return 1

  # Columns of 'fix' database file:
  # project_id,version_id,test_suite_source,test_id,num_uncompilable_tests,num_uncompilable_test_classes,num_failing_tests
  local expected_db_data="$pid,$bid,test,1,0,0,1"
  _check_fix_db "$suites_dir/fix" "$expected_db_data" || return 1

  # Clean up
  rm -rf "$suites_dir"

  return 0
}

test_InvalidCharacters() { # Issue 105
  local suites_dir="$TMP_DIR/test_InvalidCharacters"

  local pid="Math"
  local bid="1b"

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/InvalidCharacters.java" "foo/bar/InvalidCharacters.java" \
    "$suites_dir" || return 1

  if ! perl -e 'use DBI; use DBD::CSV;' 2>/dev/null; then
    echo "Warning: Please make sure perl modules 'DBI' and 'DBD:CSV' are installed."
    return 0
  fi

  run_fix_test_suite_test_case "$pid" "$bid" \
    "foo/bar/InvalidCharacters.java" "foo/bar/InvalidCharacters.java" \
    "$suites_dir" \
    "-L" || return 1

  # Columns of 'fix' database file:
  # project_id,version_id,test_suite_source,test_id,num_uncompilable_tests,num_uncompilable_test_classes,num_failing_tests
  local expected_db_data="$pid,$bid,test,1,0,0,1"
  _check_fix_db "$suites_dir/fix" "$expected_db_data" || return 1

  # Clean up
  rm -rf "$suites_dir"

  return 0
}

test_FailingTests || die "Test 'test_FailingTests' has failed!"
test_InvalidImport || die "Test 'test_InvalidImport' has failed!"
test_UnitTestsWithCompilationIssues || die "Test 'test_UnitTestsWithCompilationIssues' has failed!"
test_ValidTestClass || die "Test 'test_ValidTestClass' has failed!"
test_LineCommentsWithWhitespaces || die "Test 'test_LineCommentsWithWhitespaces' has failed!"
test_InvalidCharacters || die "Test 'test_InvalidCharacters' has failed!"

