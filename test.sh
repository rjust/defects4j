#!/usr/bin/env bash

#
# This simple test script performs the following tasks:
#   - It runs the workflow described in the README file
#   - It performs the sanity check on all projects
#   - It verifies the triggering tests for all bugs
#
# TODO: we need unit tests and a better testing infrastructure.

HALT_ON_ERROR=0

# Log all errors to test.log
> test.log
die() {
    echo "Error while running: $1" >> test.log
    [ $HALT_ON_ERROR == 1 ] && exit 1
}

DIR=$(dirname $0)
BASE_DIR=$(cd $DIR; pwd)
export PATH=$PATH:$BASE_DIR/framework/bin:$BASE_DIR/framework/util

# Make sure that the project repos are available
cd $BASE_DIR/project_repos && ./get_repos.sh

################################################################################
# Test the workflow as described in README
################################################################################
# Get project info
defects4j info -p Lang || die "project info"

# Get bug info
defects4j info -p Lang -v 1 || die "bug info"

work_dir=/tmp/lang_1_buggy

# Checkout buggy version
defects4j checkout -p Lang -v 1b -w $work_dir || die "checkout"

# Verify that defects4j's config file exists 
[ -e $work_dir/.defects4j.config ] || die "read config file"
# Verify that defects4j's config file provides the correct data
grep -q "vid=1b" $work_dir/.defects4j.config || die "verify config file"
grep -q "pid=Lang" $work_dir/.defects4j.config || die "verify config file"

cd $work_dir

# Compile checked-out version
defects4j compile || die "compile"

# Run tests for checked-out version
defects4j test || die "test"

# directory for evosuite test suites
evo_dir=/tmp/evo_lang_2
# directory of result database
db_dir=/tmp/result_db

# Run EvoSuite on fixed version
run_evosuite.pl -p Lang -v 2f -n 1 -o $evo_dir -cbranch -b 10 -a 10 || die "EvoSuite"

# Run EvoSuite test suite and determine bug detection
run_bug_detection.pl -p Lang -d $evo_dir/Lang/evosuite-branch/1/ -o $db_dir || die "bug detection"
lines=`wc -l ${db_dir}/bug_detection | cut -f1 -d' '`
[ $lines -eq 2 ] || die "read bug detection results"
[ -f "$db_dir/bug_detection_log/Lang/run_bug_detection.pl.log" ] || die "read bug detection logs"
[ -f "$db_dir/bug_detection_log/Lang/evosuite-branch/2f.1.trigger.log" ] || die "read bug detection logs"
[ -f "$db_dir/bug_detection_log/Lang/evosuite-branch/2b.1.trigger.log" ] || die "read bug detection logs"

# Run EvoSuite test suite and determine mutation score
run_mutation.pl -p Lang -d $evo_dir/Lang/evosuite-branch/1/ -o $db_dir || die "mutation analysis"
lines=`wc -l ${db_dir}/mutation | cut -f1 -d' '`
[ $lines -eq 2 ] || die "read mutation results"
[ -f "$db_dir/mutation_log/Lang/run_mutation.pl.log" ] || die "read mutation logs"
[ -f "$db_dir/mutation_log/Lang/evosuite-branch/2f.mutants.log" ] || die "read mutation logs"
[ -f "$db_dir/mutation_log/Lang/evosuite-branch/2f.1.summary.csv" ] || die "read mutation logs"
[ -f "$db_dir/mutation_log/Lang/evosuite-branch/2f.1.kill.csv" ] || die "read mutation logs"
[ -f "$db_dir/mutation_log/Lang/evosuite-branch/2f.1.log" ] || die "read mutation logs"

# Run EvoSuite test suite and determine code coverage
run_coverage.pl -p Lang -d $evo_dir/Lang/evosuite-branch/1/ -o $db_dir || die "coverage analysis"
lines=`wc -l ${db_dir}/coverage | cut -f1 -d' '`
[ $lines -eq 2 ] || die "read coverage results"
[ -f "$db_dir/coverage_log/Lang/run_coverage.pl.log" ] || die "read coverage logs"
[ -f "$db_dir/coverage_log/Lang/evosuite-branch/2f.1.ser" ] || die "read coverage logs"
[ -f "$db_dir/coverage_log/Lang/evosuite-branch/2f.1.xml" ] || die "read coverage logs"

rm -rf $db_dir $evo_dir

# Run EvoSuite on buggy version
run_evosuite.pl -p Lang -v 2b -n 1 -o $evo_dir -cbranch -b 10 -a 10 || die "EvoSuite (buggy)"

# Run EvoSuite test suite and determine bug detection
run_bug_detection.pl -p Lang -d $evo_dir/Lang/evosuite-branch/1/ -o $db_dir || die "bug detection (buggy)"
lines=`wc -l ${db_dir}/bug_detection | cut -f1 -d' '`
[ $lines -eq 2 ] || die "read bug detection results (buggy)"
[ -f "$db_dir/bug_detection_log/Lang/run_bug_detection.pl.log" ] || die "read bug detection logs"
[ -f "$db_dir/bug_detection_log/Lang/evosuite-branch/2f.1.trigger.log" ] || die "read bug detection logs"
[ -f "$db_dir/bug_detection_log/Lang/evosuite-branch/2b.1.trigger.log" ] || die "read bug detection logs"

# Run EvoSuite test suite and determine mutation score
run_mutation.pl -p Lang -d $evo_dir/Lang/evosuite-branch/1/ -o $db_dir || die "mutation analysis (buggy)"
lines=`wc -l ${db_dir}/mutation | cut -f1 -d' '`
[ $lines -eq 2 ] || die "read mutation results (buggy)"
[ -f "$db_dir/mutation_log/Lang/run_mutation.pl.log" ] || die "read mutation logs"
[ -f "$db_dir/mutation_log/Lang/evosuite-branch/2b.mutants.log" ] || die "read mutation logs"
[ -f "$db_dir/mutation_log/Lang/evosuite-branch/2b.1.summary.csv" ] || die "read mutation logs"
[ -f "$db_dir/mutation_log/Lang/evosuite-branch/2b.1.kill.csv" ] || die "read mutation logs"
[ -f "$db_dir/mutation_log/Lang/evosuite-branch/2b.1.log" ] || die "read mutation logs"

# Run EvoSuite test suite and determine code coverage
run_coverage.pl -p Lang -d $evo_dir/Lang/evosuite-branch/1/ -o $db_dir || die "coverage analysis"
lines=`wc -l ${db_dir}/coverage | cut -f1 -d' '`
[ $lines -eq 2 ] || die "read coverage results"
[ -f "$db_dir/coverage_log/Lang/run_coverage.pl.log" ] || die "read coverage logs"
[ -f "$db_dir/coverage_log/Lang/evosuite-branch/2b.1.ser" ] || die "read coverage logs"
[ -f "$db_dir/coverage_log/Lang/evosuite-branch/2b.1.xml" ] || die "read coverage logs"


rm -rf $db_dir $evo_dir $work_dir
cd $BASE_DIR

################################################################################
# Run sanity check on all projects
################################################################################
for pid in Chart Closure Lang Math Time; do
    sanity_check.pl -p $pid || or die "sanity check $pid"
done

################################################################################
# Run test target on all buggy and fixed program versions, and verify trigger tests
################################################################################
work_dir=/tmp/test_trigger
for pid in Chart Closure Lang Math Time; do
    nBugs=`wc -l $BASE_DIR/framework/projects/$pid/commit-db | cut -f1 -d' '`
    for vid in `seq 1 1 $nBugs`; do
        for bid in "b" "f"; do
            defects4j checkout -p $pid -v "${vid}$bid" -w "$work_dir"
            cd $work_dir
            defects4j test || die "test version: $pid ${vid}$bid"
            
            nTrigger=`grep "\\---" $work_dir/.failing_tests | wc -l | cut -f1 -d' ' `
            # Expected number of failing tests for each fixed version is 0!
            if [ $bid == "f" ]; then
                [ $nTrigger -eq 0 ] || die "verify number of triggering tests: $pid ${vid}$bid"
                continue
            fi
            
            # Expected number of failing tests for each buggy version is equal
            # to the number of provided triggering tests
            expected=`grep "\\---" $BASE_DIR/framework/projects/$pid/trigger_tests/$vid | wc -l | cut -f1 -d' ' `
            [ $nTrigger -eq $expected ] || die "verify number of triggering tests: $pid ${vid}$bid"
            for t in `grep "\\---" $BASE_DIR/framework/projects/$pid/trigger_tests/$vid | cut -f2 -d' '`; do
                grep -q "$t" "$work_dir/.failing_tests" || die "verify name of triggering tests"
            done
        done
    done
done
rm -rf $work_dir
cd $BASE_DIR

echo
echo SUCCESSFUL
