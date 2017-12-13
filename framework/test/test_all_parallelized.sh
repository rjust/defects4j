#!/bin/bash

function detect_failed_tests {
    # wait for all parallel jobs to finish
    while [ 1 ]; do fg 2> /dev/null; [ $? == 1 ] && break; done

    # check if any of our tests failed
    if [ -e ${fail_status_file} ] ; then
        echo -n "Test(s) failed: "
        fail_outputs=(`cat $fail_status_file`)
        for fail_output in "${fail_outputs[@]}"; do
            echo "==============================================================="
            echo "$fail_output has failed"
            cat "$fail_output.out"
            echo "===================================================================="
            echo "===================================================================="
            echo "===================================================================="
            echo "===================================================================="
        done
        exit 1
    fi
}

if `pwd | grep -v '.*/defects4j/framework/test$'` > /dev/null; then
    echo "Fatal error, must be in test directory"
    exit 1
fi

# enable background tasks, through "Job Control"
set -m

echo "Running tests in parallel, only failing output will be shown (at the end)"

# will use this file to indicate failed test 
fail_status_file=.test_failed.status

# delete failed test status process and output files
[ -e $fail_status_file ] && rm ./${fail_status_file}
if ls ./*.out &> /dev/null; then
    rm ./*.out
fi

# complete scripts
complete_test_scripts=(test_tutorial.sh) #test_mutation_analysis.sh test_randoop.sh test_evosuite.sh) 

echo "Complete tests"
for script in "${complete_test_scripts[@]}"; do
    echo "carton exec $script" # let the user know what's going on
    ./_test_wrapper.sh "$script" > "$script.out" 2>&1 & # send to our wrapper
done

detect_failed_tests

# argument supplied script
PIDS=(Chart Lang)

echo "Argument suplied tests"
for pid in "${PIDS[@]}"; do
    break; # skip
    echo "carton exec test_verify_bugs.sh $pid" # let the user know what's going on
    ./_test_wrapper.sh "test_verify_bugs.sh $pid" > "test_verify_bugs.sh.$pid.out" 2>&1 & # send to our wrapper
done

detect_failed_tests
