#!/usr/bin/env bash
################################################################################
#
# This script tests the tutorial as described in Defects4J's README file.
#
################################################################################

HERE="$(cd "$(dirname "$0")" && pwd)" || { echo "cannot cd to $(dirname "$0")"; exit 2; }

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

# Get project info
defects4j info -p Lang || die "print project info"

# Get bug info
defects4j info -p Lang -b 1 || die "print bug info"

pid=Lang
bid=1
vid=${bid}b
work_dir=$TMP_DIR/$pid-$vid

# Checkout buggy version
defects4j checkout -p $pid -v $vid -w "$work_dir" || die "checkout program version $pid-$vid"

# Verify that defects4j's config file exists 
[ -e "$work_dir"/.defects4j.config ] || die "read config file"
# Verify that defects4j's config file provides the correct data
grep -q "pid=$pid" "$work_dir"/.defects4j.config || die "verify pid in config file"
grep -q "vid=$vid" "$work_dir"/.defects4j.config || die "verify vid in config file"

cd "$work_dir" || { echo "cannot cd to $work_dir"; exit 2; }

# Compile buggy version
defects4j compile || die "compile program version $pid-$vid"

# Run tests for buggy version and verify triggering tests
defects4j test -r || die "test program version $pid-$vid"
actual_file="$work_dir/failing_tests"
expected_file="$BASE_DIR/framework/projects/$pid/trigger_tests/$bid"
actual=$(num_triggers "$actual_file")
expected=$(num_triggers "$expected_file")
if [ "$actual" -ne "$expected" ] ; then
    echo "Actual triggers from $actual_file :"
    get_triggers "$actual_file"
    echo "Expected triggers from $expected_file :"
    get_triggers "$expected_file"
    die "verify number of triggering tests"
fi

vid=${bid}f
# Checkout fixed version
defects4j checkout -p $pid -v $vid -w . || die "checkout program version $pid-$vid"

# Compile fixed version
defects4j compile || die "compile program version $pid-$vid"

# Run coverage and mutation analysis
defects4j coverage -r || die "coverage analysis $pid-$vid"
defects4j mutation -r || die "coverage analysis $pid-$vid"
