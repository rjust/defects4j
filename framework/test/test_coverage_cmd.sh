#!/usr/bin/env bash
################################################################################
#
# This script runs the defects4j coverage command for all bugs or a subset of
# bugs for a given project.
#
# Examples for Lang:
#   * All bugs:         ./test_coverage_cmd.sh -pLang
#   * Bugs 1-10:        ./test_coverage_cmd.sh -pLang -b1..10
#   * Bugs 1 and 3:     ./test_coverage_cmd.sh -pLang -b1 -b3
#   * Bugs 1-10 and 20: ./test_coverage_cmd.sh -pLang -b1..10 -b20
#
################################################################################
# Import helper subroutines and variables, and init Defects4J
source test.include

# Print usage message and exit
usage() {
    local known_pids; known_pids=$(defects4j pids)
    echo "usage: $0 -p <project id> [-b <bug id> ... | -b <bug id range> ... ]"
    echo "Project ids:"
    for pid in $known_pids; do
        echo "  * $pid"
    done
    exit 1
}

# Run only relevant tests by default
TEST_FLAG_OR_EMPTY="-r"
# Debugging is off by default
DEBUG=""

# Check arguments
while getopts ":p:b:AD" opt; do
    case $opt in
        A) TEST_FLAG_OR_EMPTY=""
            ;;
        D) DEBUG="-D"
            ;;
        p) PID="$OPTARG"
            ;;
        b) if [[ "$OPTARG" =~ ^[0-9]*\.\.[0-9]*$ ]]; then
                BUGS="$BUGS $(eval "echo {$OPTARG}")"
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
    BUGS="$(get_bug_ids "$BASE_DIR/framework/projects/$PID/$BUGS_CSV_ACTIVE")"
fi

# Create log file
script_name_without_sh=${script//.sh/}
LOG="$TEST_DIR/${script_name_without_sh}$(printf '_%s_%s' "$PID" $$).log"
OUT_DIR="$TEST_DIR/${script_name_without_sh}$(printf '_%s_%s' "$PID" $$).cov"
mkdir -p "$OUT_DIR"

if [ "$DEBUG" == "-D" ]; then
    export D4J_DEBUG=1
fi

# Reproduce all bugs (and log all results), regardless of whether errors occur
HALT_ON_ERROR=0

test_dir=$(mktemp -d)
for bid in $BUGS; do
    # Skip all bug ids that do not exist in the active-bugs csv
    if ! grep -q "^$bid," "$BASE_DIR/framework/projects/$PID/$BUGS_CSV_ACTIVE"; then
        warn "Skipping bug ID that is not listed in active-bugs csv: $PID-$bid"
        continue
    fi

    # Test mutation analysis for the fixed version only.
    vid="${bid}f"
    work_dir="$test_dir/$PID-$vid"
    defects4j checkout -p "$PID" -v "$vid" -w "$work_dir" || die "checkout: $PID-$vid"
    if defects4j coverage "$TEST_FLAG_OR_EMPTY" -w "$work_dir"; then
      cp "$work_dir/summary.csv" "$OUT_DIR/$PID-$bid.summary.csv"
    else 
      echo "ERROR: $PID-$bid" > "$OUT_DIR/$PID-$bid.summary.error"
    fi
    cp "$work_dir/all_tests" "$OUT_DIR/$PID-$bid.tests.txt"
done
rm -rf "$test_dir"
HALT_ON_ERROR=1

# Print a summary of what went wrong
if [ $ERROR != 0 ]; then
    printf '=%.s' $(seq 1 80) 1>&2
    echo 1>&2
    echo "The following errors occurred:" 1>&2
    cat "$LOG" 1>&2
fi

# Indicate whether an error occurred
exit $ERROR
