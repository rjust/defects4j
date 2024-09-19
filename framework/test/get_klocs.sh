#!/usr/bin/env bash
################################################################################
#
# This script counts the KLOCS of tests in the defects4j suite.
# An optional first agument will replace the default project list.
# An optional second agument will replace the default bid list.
#
################################################################################

# Must use Java version 8.
JAVA_VERSION_STRING=$(java -version 2>&1 | head -1)
# shellcheck disable=SC2001 # variable substitution does not suffice; needs sed.
JAVA_RELEASE_NUMBER=$(echo "$JAVA_VERSION_STRING" | sed 's/^.*1\.\(.\).*/\1/')
if [[ "$JAVA_RELEASE_NUMBER" != "8" ]]; then
 echo Must use Java version 8
 exit
fi

# Import helper subroutines and variables, and init Defects4J
if [ ! -f test.include ]; then
    echo "File test.include not found!  Ran script from wrong directory?"
    exit 1
fi
source test.include
init

# Directory for Randoop test suites
randoop_dir=$TMP_DIR/randoop

if [ -z "$JAVA_COUNT_TOOL" ] ; then
    die "JAVA_COUNT_TOOL environment variable not set"
fi

if [ -z "$1" ] ; then
# Generate tests for all projects
    projects=( Chart Closure Lang Math Mockito Time )
# Generate tests for all bids
    bids=( 1 2 3 4 5 )
else
# Generate tests for supplied project list
    # shellcheck disable=SC2206 # $1 is a list.
    projects=( $1 )
    if [ -z "$2" ] ; then
# Generate tests for all bids
        bids=( 1 2 3 4 5 )
    else
# Generate tests for supplied bid list
        # shellcheck disable=SC2206 # #2 is a list
        bids=( $2 )
    fi
fi

echo "Projects: " "${projects[@]}"
echo "Bug ids: " "${bids[@]}"

# We want the 'fixed' version of the sample.
type=f

for pid in "${projects[@]}"; do
    for bid in "${bids[@]}"; do
        vid=${bid}$type

        run_klocs.pl -p "$pid" -v "$vid" -n 1 -o "$randoop_dir" || die "run klocs on $pid-$vid"
    done
done

# delete tmp file directory
rm -rf "$randoop_dir"
