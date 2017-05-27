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

pid="Math" # any pid-bid should work
bid="1b"

# Create a directory for test suites
suites_dir="$TMP_DIR/test_suites_dir"
rm -rf "$suites_dir"
mkdir -p "$suites_dir"

# Create a .tar.bz2 file with all test suites
pushd . > /dev/null 2>&1
cd "$HERE/resources/input"
  tar_bz2_file="$suites_dir/$pid-$bid-test.0.tar.bz2"
  tar -jcvf "$tar_bz2_file" \
    foo/bar/InvalidImport.java \
    foo/bar/UnitTestsWithCompilationIssues.java \
    foo/bar/ValidTestClass.java || die "Was not possible to create '$tar_bz2_file' file!"
popd > /dev/null 2>&1

# Fix test suites
fix_test_suite.pl -p "$pid" -d "$suites_dir" -v "$bid" || die "Script 'fix_test_suite.pl' has failed!"

tar -jxvf "$tar_bz2_file" -C "$suites_dir"

# Check output of 'fix_test_suite.pl' script

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

rm -rf "$suites_dir"

# EOF

