#!/usr/bin/env bash
################################################################################
#
# This script tests the D4J's mutation analysis script.
#
################################################################################
# TODO: There is some code duplication in this test script, which we can avoid
# by extracting the mutation analysis workflow into a parameterized function.

HERE="$(cd "$(dirname "$0")" && pwd)" || { echo "cannot cd to $(dirname "$0")"; exit 2; }

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

main() {
    # Any fixed project version should work, but test cases are version-specific
    _set_vars "Cli" "12f"
    # Clean temporary directory
    rm -rf "$pid_vid_dir"

    # Checkout project-version
    defects4j checkout -p "$pid" -v "$vid" -w "$pid_vid_dir" || die "It was not possible to checkout $pid-$vid to '$pid_vid_dir'!"

    ######################################################
    # Test mutation analysis without excluding any mutants

    # Remove the summary file to ensure it is regenerated
    rm -f "$summary_file"

    defects4j mutation -w "$pid_vid_dir" -r || die "Mutation analysis (including all mutants) failed!"
    _check_mutation_result 62 62 62 53

    ###################################################
    # Test mutation analysis when excluding all mutants

    # Remove the summary file to ensure it is regenerated
    rm -f "$summary_file"

    # Exclude all generated mutants
    exclude_file="$pid_vid_dir/exclude_all_mutants.txt"
    cut -f1 -d':' "$mutants_file" > "$exclude_file"

    defects4j mutation -w "$pid_vid_dir" -r -e "$exclude_file" || die "Mutation analysis (excluding all mutants) failed!"
    _check_mutation_result 62 0 0 0

    ##########################################################################
    # Test mutation analysis when explicitly providing a subset of operators

    # Remove the summary file to ensure it is regenerated
    rm -f "$summary_file"

    # Use three mutation operators (test space and newline separation)
    mut_ops_file="$pid_vid_dir/mut_ops.txt"
    echo "AOR LVR" > "$mut_ops_file"
    echo "ROR" >> "$mut_ops_file"

    defects4j mutation -w "$pid_vid_dir" -r -m "$mut_ops_file" || die "Mutation analysis (subset of mutation operators) failed!"
    _check_mutation_result 33 33 33 30


    ##########################################################################
    # Test mutation analysis when explicitly providing the class(es) to mutate

    # Remove the summary file to ensure it is regenerated
    rm -f "$summary_file"

    # Mutate an arbitrary, non-modified class
    instrument_classes="$pid_vid_dir/instrument_classes.txt"
    echo "org.apache.commons.cli.Util" > "$instrument_classes"

    defects4j mutation -w "$pid_vid_dir" -r -i "$instrument_classes" || die "Mutation analysis (instrument Util.java) failed!"
    _check_mutation_result 25 25 25 24

    # Clean up
    rm -rf "$pid_vid_dir"

    ##########################################################################
    # Test mutation analysis for other projects

    # Chart-12f
    _set_vars "Chart" "12f"
    # Remove temporary directory if it already exists
    rm -rf "$pid_vid_dir"
    # Checkout project-version
    defects4j checkout -p "$pid" -v "$vid" -w "$pid_vid_dir" || die "It was not possible to checkout $pid-$vid to '$pid_vid_dir'!"
    # Remove the summary file to ensure it is regenerated
    rm -f "$summary_file"
    defects4j mutation -w "$pid_vid_dir" -r || die "Mutation analysis (including all mutants) failed!"
    _check_mutation_result 238 238 59 32
    # Clean up
    rm -rf "$pid_vid_dir"

    # Mockito-12f
    _set_vars "Mockito" "12f"
    # Remove temporary directory if it already exists
    rm -rf "$pid_vid_dir"
    # Checkout project-version
    defects4j checkout -p "$pid" -v "$vid" -w "$pid_vid_dir" || die "It was not possible to checkout $pid-$vid to '$pid_vid_dir'!"
    # Remove the summary file to ensure it is regenerated
    rm -f "$summary_file"
    defects4j mutation -w "$pid_vid_dir" -r || die "Mutation analysis (including all mutants) failed!"
    _check_mutation_result 7 7 7 4
    # Clean up
    rm -rf "$pid_vid_dir"

    # Time-14f (requires major-rt.jar on the cp)
    _set_vars "Time" "14f"
    # Remove temporary directory if it already exists
    rm -rf "$pid_vid_dir"
    # Checkout project-version
    defects4j checkout -p "$pid" -v "$vid" -w "$pid_vid_dir" || die "It was not possible to checkout $pid-$vid to '$pid_vid_dir'!"
    # Remove the summary file to ensure it is regenerated
    rm -f "$summary_file"
    defects4j mutation -w "$pid_vid_dir" -r || die "Mutation analysis (including all mutants) failed!"
    _check_mutation_result 327 327 231 199
    # Clean up
    rm -rf "$pid_vid_dir"

# TODO: Test execution against the generated mutants fails for some Mockito
# versions due to an incorrect classpath. Reenable this tests once the
# underlying issue is resolved.
#    # Mockito-4f (gradle build + call to major/bin/major from gradle)
#    _set_vars "Mockito" "4f"
#    # Remove temporary directory if it already exists
#    rm -rf "$pid_vid_dir"
#    # Checkout project-version
#    defects4j checkout -p "$pid" -v "$vid" -w "$pid_vid_dir" || die "It was not possible to checkout $pid-$vid to '$pid_vid_dir'!"
#    # Remove the summary file to ensure it is regenerated
#    rm -f "$summary_file"
#    defects4j mutation -w "$pid_vid_dir" -r || die "Mutation analysis (including all mutants) failed!"
#    _check_mutation_result 7 7 7 4
#    # Clean up
#    rm -rf "$pid_vid_dir"
}

################################################################################
#
# Set variables used by the test script, based on provided PID and VID
#
_set_vars() {
    # Set PID, VID, and the temporary directory
    pid="$1"
    vid="$2"
    pid_vid_dir="$TMP_DIR/$pid-$vid"

    # Files generated by Major
    summary_file="$pid_vid_dir/summary.csv"
    mutants_file="$pid_vid_dir/mutants.log"
    kill_file="$pid_vid_dir/kill.csv"
}

################################################################################
#
# Check whether the mutation analysis results (summary.csv) match the expectations.
#
_check_mutation_result() {
    [ $# -eq 4 ] || die "usage: ${FUNCNAME[0]} \
            <expected_mutants_generated> \
            <expected_mutants_retained> \
            <expected_mutants_covered> \
            <expected_mutants_killed>"
    local exp_mut_gen=$1
    local exp_mut_ret=$2
    local exp_mut_cov=$3
    local exp_mut_kill=$4

    # Make sure Major generated the expected data files
    [ -s "$mutants_file" ] || die "'$mutants_file' doesn't exist or is empty!"
    [ -s "$summary_file" ] || die "'$summary_file' doesn't exist or is empty!"
    [ -s "$kill_file" ] || die "'$kill_file' doesn't exist or is empty!"

    # The last row of 'summary.csv' does not have an end of line character.
    # Otherwise, using wc would be more intuitive.
    local num_rows; num_rows=$(grep -c "^" "$summary_file")
    [ "$num_rows" -eq "2" ] || die "Unexpected number of lines in '$summary_file'!"

    # Columns of summary (csv) file:
    # MutantsGenerated,MutantsRetained,MutantsCovered,MutantsKilled,MutantsLive,RuntimePreprocSeconds,RuntimeAnalysisSeconds
    local act_mut_gen; act_mut_gen=$(tail -n1  "$summary_file" | cut -f1 -d',')
    local act_mut_ret; act_mut_ret=$(tail -n1  "$summary_file" | cut -f2 -d',')
    local act_mut_cov; act_mut_cov=$(tail -n1  "$summary_file" | cut -f3 -d',')
    local act_mut_kill; act_mut_kill=$(tail -n1 "$summary_file" | cut -f4 -d',')

    [ "$act_mut_gen"  -eq "$exp_mut_gen" ] || die "Unexpected number of mutants generated (expected: $exp_mut_gen, actual: $act_mut_gen)!"
    [ "$act_mut_ret"  -eq "$exp_mut_ret" ] || die "Unexpected number of mutants retained (expected: $exp_mut_ret, actual: $act_mut_ret)!"
    [ "$act_mut_cov"  -eq "$exp_mut_cov" ] || die "Unexpected number of mutants covered (expected: $exp_mut_cov, actual: $act_mut_cov)!"
# TODO: The CI runs lead to additional timeouts for some mutants, which breaks
# this test. Change the test to check the kill results themselves and ignore
# timeouts when counting the expected number of detected mutants.
    [ "$act_mut_kill" -eq "$exp_mut_kill" ] || die "Unexpected number of mutants killed (expected: $exp_mut_kill, actual: $act_mut_kill)!"

    # TODO Would be nice to test the number of excluded mutants. In order to do it
    # Major has to write that number to the '$pid_vid_dir/summary.csv' file.
}
################################################################################

main
