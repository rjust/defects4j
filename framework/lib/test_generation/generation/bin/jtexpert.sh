#!/bin/sh
#
# Template wrapper script for a test generation tool
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
for class in $(cat $D4J_FILE_TARGET_CLASSES); do
    file=$(get_abs_src_path $class)
    cmd="java -jar -Xms1G -Xmx1G $D4J_DIR_TESTGEN_LIB/jtexpert-current.jar \
        -cp $(get_project_cp) \
        -jf $file \
        -maxTime $D4J_CLASS_BUDGET \
        -tp $D4J_DIR_OUTPUT \
        -seed $D4J_SEED \
        -o"

    # Print the command that failed, if an error occurred.
    if ! $cmd; then
        echo
        echo "FAILED: $cmd"
        exit 1
    fi
done
