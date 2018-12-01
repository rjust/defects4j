#!/usr/bin/env bash
################################################################################
#
# This script tests the test generation using Randoop.
#
################################################################################
# Import helper subroutines and variables, and init Defects4J
source test.include
init

# Directory for Randoop test suites
randoop_dir=$TMP_DIR/randoop
# Generate tests for Lang-2
pid=Lang
bid=2
# Test suite source and number
suite_src=randoop
suite_num=1
suite_dir=$randoop_dir/$pid/$suite_src/$suite_num

for type in f b; do
    vid=${bid}$type

    # Run Randoop and fix test suite
    run_randoop.pl -p $pid -v $vid -n 1 -o $randoop_dir -b 10 || die "run Randoop on $pid-$vid"
    fix_test_suite.pl -p $pid -d $suite_dir || die "fix test suite"

    # Run test suite and determine bug detection
    test_bug_detection $pid $suite_dir
   
    # Run test suite and determine mutation score
    test_mutation $pid $suite_dir
   
    # Run test suite and determine code coverage
    test_coverage $pid $suite_dir 0
   
    rm -rf $randoop_dir
done
