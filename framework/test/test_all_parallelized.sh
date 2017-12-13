#!/bin/bash

function detect_failed_tests {
    # wait for all parallel jobs to finish
    while [ 1 ]; do fg 2> /dev/null; [ $? == 1 ] && break; done

    # check if any of our tests failed
    if [ -e ${fail_status_file} ] ; then
        echo -n "Test(s) failed: "
        cat $fail_status_file | tr "\n" ", "
        exit 1
    fi
}

if `pwd | grep -v '.*/defects4j/framework/test$'` > /dev/null; then
    echo "Fatal error, must be in test directory"
    exit 1
fi

# enable background tasks, through "Job Control"
set +m

echo "Running tests in parallel"

# will use this file to indicate failed test 
fail_status_file=.test_failed.status
# delete failed test status process
[ -e $fail_status_file ] && rm ./${fail_status_file}

# complete scripts
complete_test_scripts=(test_tutorial.sh test_mutation_analysis.sh test_randoop.sh test_evosuite.sh) # alternativly could be `ls -1p | grep -e '^.*\.sh$'`

echo "  Complete tests"
for script in "${complete_test_scripts[@]}"; do
    { ./_test_wrapper.sh "$script" & } 2> /dev/null # send to our wrapper
done

detect_failed_tests

# argument supplied script
PIDS=(Chart Lang)

echo "  Argument suplied tests"
for pid in "${PIDS[@]}"; do
    { ./_test_wrapper.sh "test_verify_bugs.sh $pid" & } 2> /dev/null # send to our wrapper
done

detect_failed_tests
