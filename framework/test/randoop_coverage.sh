#!/usr/bin/env bash
################################################################################
#
# This script tests the test generation using Randoop.
#
################################################################################
# Import helper subroutines and variables, and init Defects4J
source test.include
init

# master coverage file
master_coverage=$TMP_DIR/coverage

# Directory for Randoop test suites
randoop_dir=$TMP_DIR/randoop

# Generate tests for all projects
# Mockito #1 and #3 don't work; problem finding classes in byte-buddy?
# Thus the strange hack below
# Also, Mockito seems to require Java 7; the rest work with 7 or 8.
projects=( Chart Closure Lang Math Mockito Time )
type=f

# Test suite source and number
suite_src=randoop
suite_num=1

# probably should be a flag whether or not to keep existing data for cumlative run(s)
#rm -f $master_coverage

for pid in "${projects[@]}"; do
    for bid in 1 2 3 4 5; do
        if [ "$pid" = 'Mockito' ]; then
            bid=$(($bid + 3))
        fi
        vid=${bid}$type
        # Run Randoop
        run_randoop.pl -p $pid -v $vid -n 1 -o $randoop_dir -b 100 || die "run Randoop on $pid-$vid"
    done

    suite_dir=$randoop_dir/$pid/$suite_src/$suite_num

    # Run generated test suites and determine code coverage
    test_coverage $pid $suite_dir 1

    cat $TMP_DIR/result_db/coverage >> $master_coverage

done

# delete all tmp files
rm -rf $randoop_dir
