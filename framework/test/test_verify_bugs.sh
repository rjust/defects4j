#!/usr/bin/env bash
################################################################################
#
# This script verifies that all bugs in Defects4J are reproducible and that the
# provided information about triggering tests is correct.
#
################################################################################
# Import helper subroutines and variables, and init Defects4J
source test.include

# Check whether only a subset of projects should be tested
if [ $# -eq 0 ]; then
    projects=( Chart Closure Lang Math Mockito Time )
else
    projects=( $* )
    script_name=$(echo $script | sed 's/\.sh$//')
    LOG="$TEST_DIR/${script_name}$(printf '_%s' $*).log"
fi
init

################################################################################
# Run developer-written tests on all buggy and fixed program versions, and 
# verify trigger tests
################################################################################

# Reproduce all bugs (and log all results), regardless of whether errors occur
HALT_ON_ERROR=0

test_dir="$TMP_DIR/test_trigger"
mkdir -p $test_dir

for pid in "${projects[@]}"; do
    num_bugs=$(num_lines $BASE_DIR/framework/projects/$pid/commit-db)
    work_dir="$test_dir/$pid"
    # Clean working directory
    rm -rf $work_dir
    for bid in $(seq 1 1 $num_bugs); do
        for v in "b" "f"; do
            vid=${bid}$v
            defects4j checkout -p $pid -v "$vid" -w "$work_dir" || die "checkout: $pid-$vid"
            defects4j compile -w "$work_dir" || die "compile: $pid-$vid"
            defects4j test -r -w "$work_dir" || die "run relevant tests: $pid-$vid"
            
            triggers=$(num_triggers "$work_dir/failing_tests")
            # Expected number of failing tests for each fixed version is 0!
            if [ $v == "f" ]; then
                [ $triggers -eq 0 ] \
                        || die "verify number of triggering tests: $pid-$vid (expected: 0, actual: $triggers)"
                continue
            fi
            
            # Expected number of failing tests for each buggy version is equal
            # to the number of provided triggering tests
            expected=$(num_triggers "$BASE_DIR/framework/projects/$pid/trigger_tests/$bid")
            [ $triggers -eq $expected ] \
                    || die "verify number of triggering tests: $pid-$vid (expected: $expected, actual: $triggers)"
            for t in $(get_triggers "$BASE_DIR/framework/projects/$pid/trigger_tests/$bid"); do
                grep -q "$t" "$work_dir/failing_tests" || die "verify name of triggering tests ($t not found)"
            done
        done
    done
    rm -rf $work_dir
done
HALT_ON_ERROR=1
