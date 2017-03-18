#!/bin/sh
#
# Wrapper script for Evosuite
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

for class in $(cat $D4J_FILE_TARGET_CLASSES); do
    cmd="java -cp $D4J_DIR_TESTGEN_LIB/evosuite-current.jar org.evosuite.EvoSuite \
    -class $class \
    -projectCP $(get_project_cp) \
    -criterion branch \
    -seed $D4J_SEED \
    -Dsearch_budget=$D4J_CLASS_BUDGET \
    -Dstopping_condition=MaxTime \
    -Dtest_dir=$D4J_DIR_OUTPUT \
    -Dassertion_timeout=30 \
    -Dshow_progress=false \
    -Djunit_check=false \
    -Dfilter_assertions=false \
    -Dtest_comments=false \
    -mem 1500"

    # Print the command that failed, if an error occurred.
    if ! $cmd; then
        echo
        echo "FAILED: $cmd"
        exit 1
    fi
done
