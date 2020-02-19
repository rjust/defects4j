#!/usr/bin/env bash
#
# Wrapper script for Evosuite
#
# Environment variables exported by Defects4J's gen_tests.pl script:
# D4J_HOME:                The root directory of the used Defects4J installation.
# D4J_FILE_TARGET_CLASSES: File that lists all target classes (one per line).
# D4J_DIR_OUTPUT:          Directory to which the generated test suite sources
#                          should be written.
# D4J_DIR_WORKDIR:         Defects4J working directory of the checked-out
#                          project version.
# D4J_DIR_TESTGEN_BIN:     Directory that provides all scripts and configs of
#                          all test-generation tools (directory of this script).
# D4J_DIR_TESTGEN_LIB:     Directory that provides the libraries of all
#                          test-generation tools.
# D4J_TOTAL_BUDGET:        The total budget (in seconds) that the tool should
#                          spend at most for all target classes.
# D4J_SEED:                The random seed.
# D4J_TEST_MODE:           Test mode: "regression" or "error-revealing".
# D4J_DEBUG:               Run in debug mode: 0 (no) or 1 (yes).

# Check whether the D4J_DIR_TESTGEN_BIN variable is set
if [ -z "$D4J_DIR_TESTGEN_BIN" ]; then
    echo "Variable D4J_DIR_TESTGEN_BIN not set!"
    exit 1
fi

# General helper functions
source $D4J_DIR_TESTGEN_BIN/_tool.source

# The classpath to compile and run the project
project_cp=$(get_project_cp)

# Read all additional configuration parameters
add_config=$(parse_config $D4J_DIR_TESTGEN_BIN/evosuite.config)

# Make sure the provided test mode is supported
if [ $D4J_TEST_MODE != "regression" ]; then
    die "Unsupported test mode: $D4J_TEST_MODE"
fi

# Compute the budget per target class; evenly split the time for search and assertions
num_classes=$(cat $D4J_FILE_TARGET_CLASSES | wc -l)
budget=$(echo "$D4J_TOTAL_BUDGET/2/$num_classes" | bc)

for class in $(cat $D4J_FILE_TARGET_CLASSES); do
    cmd="java -cp $D4J_DIR_TESTGEN_LIB/evosuite-current.jar org.evosuite.EvoSuite \
    -class $class \
    -projectCP $project_cp \
    -seed $D4J_SEED \
    -Dsearch_budget=$budget \
    -Dassertion_timeout=$budget \
    -Dtest_dir=$D4J_DIR_OUTPUT \
    $add_config"

    # Run the test-generation command
    if ! exec_cmd "$cmd"; then
        exit 1
    fi
done
