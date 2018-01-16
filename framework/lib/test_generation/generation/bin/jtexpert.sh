#!/usr/bin/env bash
#
# Wrapper script for JTExpert
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

################################################################################
# JTExpert command-line options:
#  -cp: to set the class path
#  -jf: to set the Java file under test
#  -maxTime: to set the time limit
#  -tp: to set the work directory, wherein the test suite will be saved.
#  -p: to print a progress bar
#  -s: to show messages and errors thrown by the class under test
#  -o: to override an existing test data file
################################################################################
mkdir -p $D4J_DIR_OUTPUT
for class in $(cat $D4J_FILE_TARGET_CLASSES); do
    file=$(get_abs_src_path $class)
    cmd="java -jar -Xms1G -Xmx1G $D4J_DIR_TESTGEN_LIB/jtexpert-current.jar \
        -cp $(get_project_cp) \
        -jf $file \
        -maxTime $D4J_CLASS_BUDGET \
        -tp $D4J_DIR_WORKDIR/jte-tmp \
        -seed $D4J_SEED \
        -o"

    # TODO: Check why JTExpert returns an error code even though it generates a
    # test suite.
    $cmd

    # Print the command that failed, if an error occurred.
    #if ! $cmd; then
    #    echo
    #    echo "FAILED: $cmd"
    #    exit 1
    #fi

    # Copy the generated test cases to the specified output directory
    cp -a $D4J_DIR_WORKDIR/jte-tmp/testcases/* $D4J_DIR_OUTPUT
done
