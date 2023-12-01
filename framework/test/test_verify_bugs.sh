#!/usr/bin/env bash
################################################################################
#
# This script verifies that all bugs for a given project are reproducible and
# that the provided information about triggering tests is correct.
# This script must be run from its own directory (`framework/tests/`).
#
# By default, this script runs only relevant tests. Set the -A flag to run all
# tests. Set the -D flag to enable verbose logging (D4J_DEBUG).
#
# Examples for Lang:
#   * Verify all bugs:         ./test_verify_bugs.sh -pLang
#   * Verify bugs 1-10:        ./test_verify_bugs.sh -pLang -b1..10
#   * Verify bugs 1 and 3:     ./test_verify_bugs.sh -pLang -b1 -b3
#   * Verify bugs 1-10 and 20: ./test_verify_bugs.sh -pLang -b1..10 -b20
#   * Verify bug 2 with DEBUG  ./test_verify_bugs.sh -pLang -b 2 -D
#
################################################################################
# Import helper subroutines and variables, and init Defects4J
source test.include

# Print usage message and exit
usage() {
    local known_pids=$(defects4j pids)
    echo "usage: $0 -p <project id> [-b <bug id> ... | -b <bug id range> ... ] [-D]"
    echo "Project ids:"
    for pid in $known_pids; do
        echo "  * $pid"
    done
    exit 1
}

# Run only relevant tests by default
TEST_FLAG="-r"
# Debugging is off by default
DEBUG=""

# Check arguments
while getopts ":p:b:AD" opt; do
    case $opt in
        A) TEST_FLAG=""
            ;;
        D) DEBUG="-D"
            ;;
        p) PID="$OPTARG"
            ;;
        b) if [[ "$OPTARG" =~ ^[0-9]*\.\.[0-9]*$ ]]; then
                BUGS="$BUGS $(eval echo {$OPTARG})"
           else
                BUGS="$BUGS $OPTARG"
           fi
            ;;
        \?)
            echo "Unknown option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "No argument provided: -$OPTARG." >&2
            usage
            ;;
  esac
done

if [ "$PID" == "" ]; then
    usage
fi

if [ ! -e "$BASE_DIR/framework/core/Project/$PID.pm" ]; then
    usage
fi

init

# Run all bugs, unless otherwise specified
if [ "$BUGS" == "" ]; then
    BUGS="$(get_bug_ids $BASE_DIR/framework/projects/$PID/$BUGS_CSV_ACTIVE)"
fi

if [ "$DEBUG" == "-D" ]; then
    export D4J_DEBUG=1
fi

# Create log file
script_name=$(echo $script | sed 's/\.sh$//')
LOG="$TEST_DIR/${script_name}$(printf '_%s_%s' $PID $$).log"
DIR_FAILING="$TEST_DIR/${script_name}$(printf '_%s_%s' $PID $$).failing_tests"

################################################################################
# Run developer-written tests on all buggy and fixed program versions, and 
# verify trigger tests
################################################################################

# Reproduce all bugs (and log all results), regardless of whether errors occur
HALT_ON_ERROR=0

test_dir="$TMP_DIR/test_trigger"
mkdir -p $test_dir

mkdir -p $DIR_FAILING

work_dir="$test_dir/$PID"

function sed_cmd()
{
    if [ $(uname -s) = "Darwin" ]; then
        sed -i '' "$1" $2
    else
        sed -i "$1" $2
    fi
}

# Clean working directory
rm -rf $work_dir
for bid in $(echo $BUGS); do
    # Skip all bug ids that do not exist in the active-bugs csv
    if ! grep -q "^$bid," "$BASE_DIR/framework/projects/$PID/$BUGS_CSV_ACTIVE"; then
        warn "Skipping bug ID that is not listed in active-bugs csv: $PID-$bid"
        continue
    fi

    for v in "b" "f"; do
        vid=${bid}$v
        defects4j checkout -p $PID -v "$vid" -w "$work_dir" || die "checkout: $PID-$vid"
        case $PID in
            Cli|Time)
                # doesn't always exist
                sed_cmd "s/source=\"1\.[1-5]\"/source=\"1.6\"/" $work_dir/maven-build.xml
                sed_cmd "s/target=\"1\.[1-5]\"/target=\"1.6\"/" $work_dir/maven-build.xml
                # only used when no maven-build.xml
                sed_cmd "s/source=\"1\.[1-5]\"/source=\"1.6\"/" $work_dir/build.xml
                sed_cmd "s/target=\"1\.[1-5]\"/target=\"1.6\"/" $work_dir/build.xml
                ;;
            Closure)
                sed_cmd "s/target-jvm: 1\.[1-5]/target-jvm 1.6/" $work_dir/lib/rhino/build.properties
                sed_cmd "s/source-level: 1\.[1-5]/source-level 1.6/" $work_dir/lib/rhino/build.properties
                sed_cmd "s/target-jvm: 1\.[1-5]/target-jvm 1.6/" $work_dir/lib/rhino/src/mozilla/js/rhino/build.properties
                sed_cmd "s/source-level: 1\.[1-5]/source-level 1.6/" $work_dir/lib/rhino/src/mozilla/js/rhino/build.properties
                ;;
            Codec)
                sed_cmd "s/1\.[1-5]/1.6/" $work_dir/default.properties
                ;;
            Compress|Csv|Jsoup)
                sed_cmd "s/source=\"1\.[1-5]\"/source=\"1.6\"/" $work_dir/maven-build.xml
                sed_cmd "s/target=\"1\.[1-5]\"/target=\"1.6\"/" $work_dir/maven-build.xml
                ;;
            Gson)
                sed_cmd "s/source=\"1\.[1-5]\"/source=\"1.6\"/" $work_dir/gson/maven-build.xml
                sed_cmd "s/target=\"1\.[1-5]\"/target=\"1.6\"/" $work_dir/gson/maven-build.xml
                ;;
            Lang)
                # either this
                sed_cmd "s/source=\"1\.[1-5]\"/source=\"1.6\"/" $work_dir/maven-build.xml
                sed_cmd "s/target=\"1\.[1-5]\"/target=\"1.6\"/" $work_dir/maven-build.xml
                # or this
                sed_cmd "s/1\.[1-5]/1.6/" $work_dir/default.properties
                ;;
            Math)
                sed_cmd "s/value=\"1\.[1-5]\"/value=\"1.6\"/" $work_dir/build.xml
                ;;
            Mockito)
                # some bids use gradle
                sed_cmd "s/sourceCompatibility = 1\.[1-5]/sourceCompatibility=1.6/" $work_dir/build.gradle
                sed_cmd "s/targetCompatibility = 1\.[1-5]/targetCompatibility=1.6/" $work_dir/build.gradle
                sed_cmd "s/gradle-1.12-bin/gradle-4.9-bin/" $work_dir/gradle/wrapper/gradle-wrapper.properties
                sed_cmd "s/gradle-2.2.1-all/gradle-4.9-bin/" $work_dir/gradle/wrapper/gradle-wrapper.properties
                sed_cmd "s/0.7-groovy-1.8/1.1-groovy-2.4/" $work_dir/buildSrc/build.gradle
                # and some bids don't
                sed_cmd "s/source=\"1\.[1-5]\"/source=\"1.6\"/" $work_dir/build.xml
                sed_cmd "s/target=\"1\.[1-5]\"/target=\"1.6\"/" $work_dir/build.xml
                ;;
        esac

        defects4j compile -w "$work_dir" || die "compile: $PID-$vid"
        defects4j test $TEST_FLAG -w "$work_dir" || die "run relevant tests: $PID-$vid"

        cat "$work_dir/failing_tests" > "$DIR_FAILING/$vid"

        triggers=$(num_triggers "$work_dir/failing_tests")
        # Expected number of failing tests for each fixed version is 0!
        if [ $v == "f" ]; then
            [ $triggers -eq 0 ] \
                    || die "verify number of triggering tests: $PID-$vid (expected: 0, actual: $triggers)"
            continue
        fi

        # Expected number of failing tests for each buggy version is equal
        # to the number of provided triggering tests
        expected=$(num_triggers "$BASE_DIR/framework/projects/$PID/trigger_tests/$bid")

        # Fail if there are no trigger tests
        [ $expected -gt 0 ] || die "Metadata error: There are no trigger tests for $PID-$vid"

        [ $triggers -eq $expected ] \
                || die "verify number of triggering tests: $PID-$vid (expected: $expected, actual: $triggers)"
        for t in $(get_triggers "$BASE_DIR/framework/projects/$PID/trigger_tests/$bid"); do
            grep -q "$t" "$work_dir/failing_tests" || die "expected triggering test $t did not fail"
        done
    done
done

if [ "$DEBUG" != "-D" ]; then
    rm -rf $TMP_DIR
fi
HALT_ON_ERROR=1

# Print a summary of what went wrong
if [ $ERROR != 0 ]; then
    printf '=%.s' $(seq 1 80) 1>&2
    echo 1>&2
    echo "The following errors occurred:" 1>&2
    cat $LOG 1>&2
fi

# Indicate whether an error occurred
exit $ERROR
