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
# Generate tests for Lang-2 (modified classes) and Lang-62 (all relevant classes)
pid=Lang
bid_mod=2
bid_all=62
# Test suite source and number
suite_src=evosuite-branch
suite_num=1
suite_dir=$evo_dir/$pid/$suite_src/$suite_num

# Verify that each target class is tested
# EvoSuite should generate one test class per target class
check_target_classes() {
    [ $# -eq 3 ] || die "usage: ${FUNCNAME[0]} <vid> <bid> <classes_dir>"
    local vid=$1
    local bid=$2
    local classes_dir=$3

    for class in $(cat "$BASE_DIR/framework/projects/$pid/$classes_dir/${bid}.src"); do
        file=$(echo $class | tr '.' '/')
        bzgrep -q "$file" "$suite_dir/${pid}-${vid}-evosuite-branch.${suite_num}.tar.bz2" || die "verify target classes ($class not found)"
    done
}

# Generate 4 test suites: buggy/fixed version X modified/loaded classes
for type in f b; do
    # Run EvoSuite for all modified classes and check whether all target classes are tested
    vid=${bid_mod}$type
    run_evosuite.pl -p $pid -v $vid -n $suite_num -o $evo_dir -cbranch -b 30 -a 10 || die "run EvoSuite (modified classes) on $pid-$vid"
    check_target_classes $vid $bid_mod "modified_classes"

    # Run EvoSuite for all loaded classes and check whether all target classes are tested
    vid=${bid_all}$type
    run_evosuite.pl -p $pid -v $vid -n $suite_num -o $evo_dir -cbranch -A -b 30 -a 10 || die "run EvoSuite (loaded classes) on $pid-$vid"
    check_target_classes $vid $bid_all "loaded_classes"
done

# Fix all test suites
fix_test_suite.pl -p $pid -d $suite_dir

# Run test suites and determine bug detection
test_bug_detection $pid $suite_dir

# Run test suites and determine mutation score
test_mutation $pid $suite_dir

# Run test suites and determine code coverage
test_coverage $pid $suite_dir

rm -rf $evo_dir
