#!/usr/bin/env bash
################################################################################
#
# This script generates coverage data for Randoop generated tests over the defects4j suite.
# By default, it does so for just 6 projects and bug ids 1-5 in each project.
# An optional first agument will replace the default project list.
# An optional second agument will replace the default bid list.
#
################################################################################

# Must use Java version 8.
JAVA_VERSION_STRING=`java -version 2>&1 | head -1`
JAVA_RELEASE_NUMBER=`echo $JAVA_VERSION_STRING | sed 's/^.*1\.\(.\).*/\1/'`
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
export TMP_DIR

# Don't exit on first error
HALT_ON_ERROR=0

# master coverage file
master_coverage=$TMP_DIR/coverage

# Directory for Randoop test suites
randoop_dir=$TMP_DIR/randoop

if [ -z "$1" ] ; then
    # Deafult = generate tests for 6 projects
    projects=( Chart Closure Lang Math Mockito Time )
    # Default = first 5 bug ids only
    bids=( 1 2 3 4 5 )
else
# Generate tests for supplied project list
    projects=( $1 )
    if [ -z "$2" ] ; then
        # Default = first 5 bug ids only
        bids=( 1 2 3 4 5 )
    else
# Generate tests for supplied bid list
        bids=( $2 )
    fi
fi

echo "Projects: ${projects[@]}"
echo "Bug ids: ${bids[@]}"

# We want the 'fixed' version of the sample.
type=f

# Test suite source and number
suite_src=randoop
suite_num=1

# probably should be a flag whether or not to keep existing data for cumlative run(s)
#rm -f $master_coverage

for pid in "${projects[@]}"; do
    for bid in "${bids[@]}"; do
        vid=${bid}$type

        # Run Randoop
        gen_tests.pl -g randoop -p $pid -v $vid -n 1 -o $randoop_dir -b 100 || die "run Randoop on $pid-$vid"
    done

    suite_dir=$randoop_dir/$pid/$suite_src/$suite_num

    # Run generated test suite and determine code coverage
    test_coverage $pid $suite_dir 1

    cat $TMP_DIR/result_db/coverage >> $master_coverage

done

# delete tmp file directory
rm -rf $randoop_dir

../util/show_coverage.pl "$TMP_DIR"/coverage
