#!/usr/bin/env bash
################################################################################
#
# This script computes code-level stats for all bugs or a subset of
# bugs for a given project.
#
# Examples for Lang:
#   * All bugs:         ./get_stats.sh -pLang
#   * Bugs 1-10:        ./get_stats.sh -pLang -b1..10
#   * Bugs 1 and 3:     ./get_stats.sh -pLang -b1 -b3
#   * Bugs 1-10 and 20: ./get_stats.sh -pLang -b1..10 -b20
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

# Check arguments
while getopts ":p:b:" opt; do
    case $opt in
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

# Make sure cloc is available
cloc --version > /dev/null 2>&1 || die "Cannot execute cloc -- make sure it is executable and on the PATH!"

# Run all bugs, unless otherwise specified
if [ "$BUGS" == "" ]; then
    BUGS="$(get_bug_ids "$BASE_DIR/framework/projects/$PID/$BUGS_CSV_ACTIVE")"
fi

# Create log file
script_name_without_sh=${script//.sh/}
LOG="$TEST_DIR/${script_name_without_sh}$(printf '_%s_%s' "$PID" $$).log"
OUT_DIR="$TEST_DIR/${script_name_without_sh}$(printf '_%s_%s' "$PID" $$).stats"
mkdir -p "$OUT_DIR"

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
    # All test cases
    defects4j test -w "$work_dir" || die "test (all): $PID-$vid"
    cp "$work_dir/all_tests" "$OUT_DIR/$PID-$bid.tests.all"
    # Relevant test cases
    defects4j test -r -w "$work_dir" || die "test (rel): $PID-$vid"
    cp "$work_dir/all_tests" "$OUT_DIR/$PID-$bid.tests.relevant"
    # Trigger test cases; NOTE the missing newline at the end of the output
    defects4j export -p tests.trigger -w "$work_dir" > "$OUT_DIR/$PID-$bid.tests.trigger"
    echo >> "$OUT_DIR/$PID-$bid.tests.trigger"

    # CLOC
    dir_src=$(defects4j export -p dir.src.classes -w "$work_dir")
    dir_test=$(defects4j export -p dir.src.tests -w "$work_dir")
    cloc "$work_dir/$dir_src" --json > "$OUT_DIR/$PID-$bid.cloc.src.json"
    cloc "$work_dir/$dir_test" --json > "$OUT_DIR/$PID-$bid.cloc.test.json"

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
