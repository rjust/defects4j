#!/bin/sh
#
# Wrapper script for T3
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

# Create the output directory
mkdir -p $D4J_DIR_OUTPUT

# Main class to invoke
main=Sequenic.T3.DerivativeSuiteGens.Gen2.G2_forSBST2016

# Arguments for G2_forSBST2016
# arg0: generate
# arg1: CUTname
# arg2: CUTroot-directory
# arg3: tracefile-directory
# arg4: junitDir
# arg5: time-budget
# arg6: worklist-type:  standard/random/lowcovfirst
# arg7: trace-refinement-heuristic: random/evo
# arg8: the maximum number of times each test-target will be refined
# arg9: number of CPU cores

# Convert from seconds to millis
budget=$(echo "$D4J_CLASS_BUDGET * 1000" | bc)
for class in $(cat $D4J_FILE_TARGET_CLASSES); do
    cmd="java -ea -cp $D4J_DIR_TESTGEN_LIB/t3-current.jar:$(get_project_cp) $main \
    generate \
    $class \
    $D4J_DIR_WORKDIR \
    $D4J_DIR_OUTPUT \
    $D4J_DIR_OUTPUT \
    $budget \
    random \
    random \
    1 \
    1"

    # Print the command that failed, if an error occurred.
    if ! $cmd; then
        echo
        echo "FAILED: $cmd"
        exit 1
    fi
done
