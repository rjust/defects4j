#!/usr/bin/env bash
#
# Wrapper script for Randoop
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
add_config=$(parse_config $D4J_DIR_TESTGEN_BIN/randoop.config)

# Make sure the provided test mode is supported
if [ $D4J_TEST_MODE == "regression" ]; then
    get_relevant_classes > "$D4J_DIR_WORKDIR/classes.randoop"
    add_config="$add_config --no-error-revealing-tests=true"
elif [ $D4J_TEST_MODE == "error-revealing" ]; then
    #get_all_classes > "$D4J_DIR_WORKDIR/classes.randoop"
    get_relevant_classes > "$D4J_DIR_WORKDIR/classes.randoop"
    add_config="$add_config --no-regression-tests=true"
else
    die "Unsupported test mode: $D4J_TEST_MODE"
fi

# Name of the wrapper regression test suite
REG_BASE_NAME=RegressionTest
ERR_BASE_NAME=ErrorTest

# Print Randoop version
version=$(java -cp $D4J_DIR_TESTGEN_LIB/randoop-current.jar randoop.main.Main | head -1)
printf "\n(%s)" "$version" >&2
printf ".%.0s" {1..expr 73 - length "$version"} >&2
printf " " >&2

# Build the test-generation command
cmd="java -ea -classpath $project_cp:$D4J_DIR_TESTGEN_LIB/randoop-current.jar \
  -Xbootclasspath/a:$D4J_DIR_TESTGEN_LIB/replacecall-current.jar \
  -javaagent:$D4J_DIR_TESTGEN_LIB/replacecall-current.jar \
  -javaagent:$D4J_DIR_TESTGEN_LIB/covered-class-current.jar \
randoop.main.Main gentests \
  --classlist=$D4J_DIR_WORKDIR/classes.randoop \
  --require-covered-classes=$D4J_FILE_TARGET_CLASSES \
  --junit-output-dir=$D4J_DIR_OUTPUT \
  --randomseed=$D4J_SEED \
  --time-limit=$D4J_TOTAL_BUDGET \
  --regression-test-basename=$REG_BASE_NAME \
  --error-test-basename=$ERR_BASE_NAME \
  $add_config"

if [ "$D4J_DEBUG" == "1" ]; then
  cmd="$cmd \
  --log=$D4J_DIR_OUTPUT/randoop-log.txt \
  --selection-log=$D4J_DIR_OUTPUT/selection-log.txt"
fi

# Run the test-generation command
if ! exec_cmd "$cmd"; then
    exit 1
fi

# Remove wrapper test suites, which are not used by Defects4J.
rm -f "$D4J_DIR_OUTPUT/${REG_BASE_NAME}.java"
rm -f "$D4J_DIR_OUTPUT/${ERR_BASE_NAME}.java"
