#!/usr/bin/env bash
################################################################################
#
# This script tests the D4J's fault localization script.
#
# Examples for Lang:
#   * Fault localization analysis of all bugs:         ./test_fault_localization.sh -pLang
#   * Fault localization analysis of bugs 1-10:        ./test_fault_localization.sh -pLang -b1..10
#   * Fault localization analysis of bugs 1 and 3:     ./test_fault_localization.sh -pLang -b1 -b3
#   * Fault localization analysis of bugs 1-10 and 20: ./test_fault_localization.sh -pLang -b1..10 -b20
#
################################################################################

HERE=$(cd `dirname $0` && pwd)

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

# -------------------------------------------------------------------- Arguments

# Print usage message and exit
usage() {
    local known_pids=$(cd "$BASE_DIR/framework/core/Project" && ls *.pm | sed -e 's/\.pm//g')
    echo "Usage: $0 -p <project id> [-b <bug id> ... | -b <bug id range> ... ]"
    echo "Project IDs:"
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

# Run all bugs, unless otherwise specified
if [ "$BUGS" == "" ]; then
    num_bugs=$(num_lines "$BASE_DIR/framework/projects/$PID/commit-db")
    BUGS="$(seq 1 1 $num_bugs)"
fi

test_fault_localization_tmp_dir="$TMP_DIR/test_fault_localization_$$/$PID"
mkdir -p "$test_fault_localization_tmp_dir"

# ------------------------------------------------------------------- Test Cases

for bid in $(echo $BUGS); do
    work_dir="$test_fault_localization_tmp_dir/$bid"

    # prepare $PID-$bid
    defects4j checkout -p "$PID" -v "${bid}b" -w "$work_dir" || die "Checkout of $PID-$bid has failed"
    defects4j compile -w "$work_dir" || die "Compilation of $PID-$bid has failed"

    # run fault localization
    defects4j fault-localization -w "$work_dir" -y sfl -e ochiai -g line || die "Execution of GZoltar on $PID-$bid has failed"

    ##
    # Sanity checks

    matrix_file="$work_dir/sfl/txt/matrix.txt"
    tests_file="$work_dir/sfl/txt/tests.csv"
    spectra_file="$work_dir/sfl/txt/spectra.csv"
    line_ochiai_ranking_file="$work_dir/sfl/txt/line.ochiai.ranking.csv"

    if [ ! -s "$work_dir/gzoltar.ser" ]; then
        die "File '$work_dir/gzoltar.ser' does not exit or it is empty!"
    elif [ ! -s "$matrix_file" ]; then
        die "File '$matrix_file' does not exit or it is empty!"
    elif [ ! -s "$tests_file" ]; then
        die "File '$tests_file' does not exit or it is empty!"
    elif [ ! -s "$spectra_file" ]; then
        die "File '$spectra_file' does not exit or it is empty!"
    elif [ ! -s "$line_ochiai_ranking_file" ]; then
        die "File '$line_ochiai_ranking_file' does not exit or it is empty!"
    fi

    # 1. Do GZoltar and D4J agree on the number of triggering test cases?

    num_triggering_test_cases_gzoltar=$(grep -a ",FAIL," "$tests_file" | wc -l)
    num_triggering_test_cases_d4j=$(grep -a "^--- " "$BASE_DIR/framework/projects/$PID/trigger_tests/$bid" | wc -l)

    if [ "$num_triggering_test_cases_gzoltar" -ne "$num_triggering_test_cases_d4j" ]; then
        die "Number of triggering test cases reported by GZoltar ($num_triggering_test_cases_gzoltar) is not the same as reported by D4J ($num_triggering_test_cases_d4j)"
    fi

    # 2. Does GZoltar and D4J agree on the list of triggering test cases?

    agree=true
    while read -r trigger_test; do
        class_test_name=$(echo "$trigger_test" | cut -f2 -d' ' | cut -f1 -d':')
        unit_test_name=$(echo "$trigger_test" | cut -f2 -d' ' | cut -f3 -d':')

        # e.g., org.apache.commons.math.complex.ComplexTest#testMath221,FAIL,3111187,junit.framework.AssertionFailedError:...
        if ! grep -a -q "^$class_test_name#$unit_test_name,FAIL," "$tests_file"; then
            echo "Triggering test case '$class_test_name#$unit_test_name' has not been reported by GZoltar"
            agree=false
        fi
    done < <(grep -a "^--- " "$BASE_DIR/framework/projects/$PID/trigger_tests/$bid")

    if [[ $agree == false ]]; then
        die "GZoltar and D4J do not agree on the list of triggering test cases"
    fi

    # 3. Has the faulty class(es) been reported?

    num_classes_not_reported=0
    modified_classes_file="$BASE_DIR/framework/projects/$PID/modified_classes/$bid.src"
    while read -r modified_class; do
        class_name=$(echo "${modified_class%.*}\$${modified_class##*.}")
        if ! grep -q "^$class_name#" "$spectra_file"; then
            echo "'$class_name' has not been reported"
            num_classes_not_reported=$((num_classes_not_reported+1))
        fi
    done < <(cat "$modified_classes_file")

    if [ "$num_classes_not_reported" -eq "1" ] && [ "$PID" == "Mockito" ] && [ "$bid" == "19" ]; then
        # one of the modified classes of Mockito-19 is an interface without
        # any code. as interfaces with no code have no lines of code in bytecode,
        # GZoltar does instrument it and therefore does not report it in the
        # spectra file
        echo "Mockito-19 excluded from the check on the number of modified classes reported"
    elif [ "$num_classes_not_reported" -ne "0" ]; then
        die "Some modified classes have not been reported by GZoltar"
    fi

    # 4. Has the faulty line(s) been covered by triggering test case(s)?

    buggy_lines_file="$BASE_DIR/framework/projects/$PID/buggy_lines/$bid.buggy.lines"
    num_buggy_lines=$(wc -l "$buggy_lines_file" | cut -f1 -d' ')

    unrankable_lines_file="$BASE_DIR/framework/projects/$PID/buggy_lines/$bid.unrankable.lines"
    num_unrankable_lines=0
    if [ -f "$unrankable_lines_file" ]; then
        num_unrankable_lines=$(wc -l "$unrankable_lines_file" | cut -f1 -d' ')
    fi

    candidates_file="$BASE_DIR/framework/projects/$PID/buggy_lines/$bid.candidates"

    if [ "$num_buggy_lines" -ne "$num_unrankable_lines" ]; then
        # find out whether all failing test cases cover at least one buggy line
        while read -r test_coverage; do
            failing_test_id=$(echo "$test_coverage" | cut -f1 -d':')
            failing_test_id=$((failing_test_id+1)) # +1 because '$tests_file' has a line header
            failing_test_name=$(awk -v n=$failing_test_id 'NR == n' "$tests_file" | cut -f1 -d',')

            test_cov_file="$work_dir/test-method-coverage.txt"
            echo "$test_coverage" | cut -f2 -d':' | awk '{for (i = 1; i <= NF; ++i) if ($i == 1) print i}' > "$test_cov_file"

            false_positive=true
            while read -r buggy_line; do
                java_file=$(echo "$buggy_line" | cut -f1 -d'#')
                line_number=$(echo "$buggy_line" | cut -f2 -d'#')

                if grep -q "^$java_file#$line_number," "$line_ochiai_ranking_file"; then
                    false_positive=false
                    break # break this while loop, as we already know that it
                    # is not a false positive
                fi
            done < <(grep -v "FAULT_OF_OMISSION" "$buggy_lines_file")

            if [[ $false_positive == true ]]; then
                # at this point, no buggy line has been found, try to find a
                # suitable candidate line, if any
                if [ -s "$candidates_file" ]; then
                    while read -r candidate_line; do
                        candidate=$(echo "$candidate_line" | cut -f2 -d',')

                        if grep -q "^$candidate," "$line_ochiai_ranking_file"; then
                            false_positive=false
                            break # break this while loop, as we already know that it
                            # is not a false positive
                        fi
                    done < <(cat "$candidates_file")
                fi
            fi

            ##
            # Known exceptions

            if [ "$PID" == "Closure" ] && [ "$bid" == "67" ]; then
                #  ) {
                # ^ buggy line to which there is not a line number in bytecode
                continue
            fi
            if [ "$PID" == "Closure" ] && [ "$bid" == "114" ]; then
                # } else {
                # ^ buggy line to which there is not a line number in bytecode
                continue
            fi
            if [ "$PID" == "Closure" ] && [ "$bid" == "119" ]; then
                # case x:
                # ^ buggy line to which there is not a line number in bytecode
                continue
            fi

            if [ "$PID" == "Math" ] && [ "$bid" == "12" ]; then
                # implements X
                # ^ buggy line to which there is not a line number in bytecode
                continue
            fi
            if [ "$PID" == "Math" ] && [ "$bid" == "104" ]; then
                # private static final double DEFAULT_EPSILON = 10e-9;
                # ^ private fields do not have a line number in bytecode
                continue
            fi

            if [ "$PID" == "Lang" ] && [ "$bid" == "29" ]; then
                # static float toJavaVersionInt(String version) {
                # ^ buggy line to which there is not a line number in bytecode
                continue
            fi
            if [ "$PID" == "Lang" ] && [ "$bid" == "56" ]; then
                # private fields are not in the bytecode
                # private Rule[] mRules;
                # private int mMaxLengthEstimate;
                # ^ the above lines do not have a line number in bytecode
                continue
            fi

            if [ "$PID" == "Mockito" ] && [ "$bid" == "8" ]; then
                # } else {
                # ^ buggy line to which there is not a line number in bytecode
                continue
            fi

            if [[ $false_positive == true ]]; then
                die "Triggering test case '$failing_test_name' does not cover any buggy line"
            fi
        done < <(grep -n " -$" "$matrix_file")
    fi
done

rm -rf "$test_fault_localization_tmp_dir"

# Indicate whether an error occurred
exit "$ERROR"

