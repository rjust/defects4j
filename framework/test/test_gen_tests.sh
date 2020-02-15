#!/usr/bin/env bash
################################################################################
#
# This script verifies that test generation tools can be executed for all bugs
# for a given project. 
#
# Examples for Lang:
#   * Generate for all bugs:         ./test_generate_suites.sh -pLang
#   * Generate for bugs 1-10:        ./test_generate_suites.sh -pLang -b1..10
#   * Generate for bugs 1 and 3:     ./test_generate_suites.sh -pLang -b1 -b3
#   * Generate for bugs 1-10 and 20: ./test_generate_suites.sh -pLang -b1..10 -b20
#
################################################################################
# Import helper subroutines and variables, and init Defects4J
source test.include
init

# Print usage message and exit
usage() {
    local known_pids=$(cd "$BASE_DIR"/framework/core/Project && ls *.pm | sed -e 's/\.pm//g')
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
    num_bugs=$(num_lines $BASE_DIR/framework/projects/$PID/commit-db)
    BUGS="$(seq 1 1 $num_bugs)"
fi

# Create log file
script_name=$(echo $script | sed 's/\.sh$//')
LOG="$TEST_DIR/${script_name}$(printf '_%s_%s' $PID $$).log"

################################################################################
# Run all generators on the specified bugs, and determine bug detection,
# mutation score, and coverage.
################################################################################

# Reproduce all bugs (and log all results), regardless of whether errors occur
HALT_ON_ERROR=0

work_dir="$TMP_DIR/$PID"
mkdir -p $work_dir

# Clean working directory
rm -rf "$work_dir/*"

for bid in $(echo $BUGS); do
    # Skip all bug ids that do not exist in the commit-db
    if ! grep -q "^$bid," "$BASE_DIR/framework/projects/$PID/commit-db"; then
        warn "Skipping bug ID that is not listed in commit-db: $PID-$bid"
        continue
    fi

    # Iterate over all supported generators

    for tool in $($BASE_DIR/framework/bin/gen_tests.pl -g help | grep \- | tr -d '-'); do
        # Directory for generated test suites
        suite_src="$tool"
        suite_num=1
        suite_dir="$work_dir/$tool/$suite_num"
        target_classes="$BASE_DIR/framework/projects/$PID/modified_classes/$bid.src"

        # Iterate over all supported generators and generate regression tests
        for type in f b; do
            vid=${bid}$type

            # Run generator and the fix script on the generated test suite
            gen_tests.pl -g "$tool" -p $PID -v $vid -n 1 -o "$TMP_DIR" -b 30 -c "$target_classes" || die "run $tool (regression) on $PID-$vid"
            fix_test_suite.pl -p $PID -d "$suite_dir" || die "fix test suite"

            # Run test suite and determine bug detection
            test_bug_detection $PID "$suite_dir"

            # Run test suite and determine mutation score
            test_mutation $PID "$suite_dir"

            # Run test suite and determine code coverage
            test_coverage $PID "$suite_dir" 0

            rm -rf $work_dir/$tool
        done
    done

    # Run Randoop and generate error-revealing tests
    gen_tests.pl -g randoop -p $PID -v ${bid}b -n 1 -o "$TMP_DIR" -b 30 -c "$target_classes" -E || die "run $tool (error-revealing) on $pid-$vid"

done
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
