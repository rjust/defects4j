#!/usr/bin/env bash
#
# Wrapper script for Randoop
#
# Exported environment variables:
# D4J_HOME:                The root directory of the used Defects4J installation.
# D4J_FILE_TARGET_CLASSES: File that lists all target classes (one per line).
# D4J_FILE_ALL_CLASSES:    File that lists all relevant classes (one per line).
# D4J_DIR_OUTPUT:          Directory to which the generated test suite sources
#                          should be written (may not exist).
# D4J_DIR_WORKDIR:         Defects4J working directory of the checked-out
#                          project version.
# D4J_DIR_TESTGEN_LIB:     Directory that provides the libraries of all
#                          testgeneration tools.
# D4J_CLASS_BUDGET:        The budget (in seconds) that the tool should spend at
#                          most per target class.
# D4J_SEED:                The random seed.

# Check whether the D4J_DIR_TESTGEN_LIB variable is set
if [ -z "$D4J_DIR_TESTGEN_LIB" ]; then
    echo "Variable D4J_DIR_TESTGEN_LIB not set!"
    exit 1
fi

# General helper functions
source $D4J_DIR_TESTGEN_LIB/bin/_tool.util

# Overall budget is #classes * class_budget
num_classes=$(cat $D4J_FILE_TARGET_CLASSES | wc -l)
budget=$(echo "$num_classes * $D4J_CLASS_BUDGET" | bc)
project_cp=$(get_project_cp)

cmd="java -ea -javaagent:$D4J_DIR_TESTGEN_LIB/randoop-agent-current.jar \
-classpath $project_cp:$D4J_DIR_TESTGEN_LIB/randoop-current.jar \
randoop.main.Main gentests \
--classlist=$D4J_FILE_ALL_CLASSES \
--junit-output-dir=$D4J_DIR_OUTPUT \
--timelimit=$budget \
--randomseed=$D4J_SEED \
--clear=10000 \
--string-maxlen=5000 \
--forbid-null=false \
--null-ratio=0.1 \
--no-error-revealing-tests=true \
--ignore-flaky-tests=true \
--only-test-public-members=false \
--include-if-class-exercised=$D4J_FILE_TARGET_CLASSES"

# Print the command that failed, if an error occurred.
if ! $cmd; then
    echo
    echo "FAILED: $cmd"
    exit 1
fi

# Remove the wrapper test suite, which isn't used by Defects4J.
if [ -e "$D4J_DIR_OUTPUT/RegressionTest.java" ]; then
    rm "$D4J_DIR_OUTPUT/RegressionTest.java"
fi
