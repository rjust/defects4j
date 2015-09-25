#!/usr/bin/env bash
################################################################################
#
# This script tests the test generation using EvoSuite.
#
################################################################################
# Import helper subroutines and variables, and init Defects4J
source test.include
init

# Directory for EvoSuite test suites
evo_dir=$TMP_DIR/evosuite
# Generate tests for Lang-2
pid=Lang
bid=2
# Test suite source and number
suite_src=evosuite-branch
suite_num=1
suite_dir=$evo_dir/$pid/$suite_src/$suite_num

for type in f b; do
    vid=${bid}$type

    # Run EvoSuite and fix test suite
    run_evosuite.pl -p $pid -v $vid -n 1 -o $evo_dir -cbranch -b 10 -a 10 || die "run EvoSuite on $pid-$vid"
    fix_test_suite.pl -p $pid -d $suite_dir

    # Run test suite and determine bug detection
    test_bug_detection $pid $suite_dir
   
    # Run test suite and determine mutation score
    test_mutation $pid $suite_dir
   
    # Run test suite and determine code coverage
    test_coverage $pid $suite_dir
   
    rm -rf $evo_dir
done
