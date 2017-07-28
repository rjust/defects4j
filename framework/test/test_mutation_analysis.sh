#!/usr/bin/env bash
################################################################################
#
# This script tests the D4J's mutation analysis script.
#
################################################################################
# TODO: There is some code duplication in this test script, which we can avoid
# by extracting the mutation analysis workflow into a parameterized function. 

HERE=$(cd `dirname $0` && pwd)

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

_test_exclude_mutants_option() {

  local pid="Lang" # any pid-bid should work
  local bid="1f"
  local pid_bid_dir="$TMP_DIR/$pid-$bid"
  rm -rf "$pid_bid_dir"

  # Checkout project-version
  defects4j checkout -p "$pid" -v "$bid" -w "$pid_bid_dir" || die "It was not possible to checkout $pid-$bid to '$pid_bid_dir'!"

  ######################################################
  # Test mutation analysis without excluding any mutants
  defects4j mutation -w "$pid_bid_dir" -r || die "Mutation analysis (including all mutants) failed!"

  # MutantsGenerated,MutantsCovered,MutantsKilled,MutantsLive,RuntimePreprocSeconds,RuntimeAnalysisSeconds
  local summary_file="$pid_bid_dir/summary.csv"
  [ -s "$summary_file" ] || die "'$summary_file' doesn't exist or is empty!"

  # The last row of 'summary.csv' does not have an end of line character.
  # Otherwise, using wc would be more intuitive.
  local num_rows=$(grep -c "^" "$summary_file")
  [ "$num_rows" -eq "2" ] || die "Unexpected number of lines in '$summary_file'!"

  local summary_data=$(awk '1' "$summary_file" | tail -n1)
  local num_mutants_covered=$(echo "$summary_data" | cut -f2 -d',')
  local num_mutants_killed=$(echo "$summary_data" | cut -f3 -d',')

  [ "$num_mutants_covered" -gt 0 ] || die "0 mutants covered!"
  [ "$num_mutants_killed" -gt 0 ] || die "0 mutants killed!"

  # TODO Would be nice to test the number of excluded mutants. In order to do it
  # Major has to write that number to the '$pid_bid_dir/summary.csv' file.

  >"$summary_file" # reset it, just in case

  ###################################################
  # Test mutation analysis when excluding all mutants

  local mutants_file="$pid_bid_dir/mutants.log"
  [ -s "$summary_file" ] || die "'$summary_file' doesn't exist or is empty!"

  local exclude_file="$pid_bid_dir/exclude_all_mutants.txt"
  cut -f1 -d':' "$mutants_file" > "$exclude_file"

  defects4j mutation -w "$pid_bid_dir" -r -e "$exclude_file" || die "Mutation analysis (excluding all mutants) failed!"

  # The last row of 'summary.csv' does not have an end of line character.
  # Otherwise, using wc would be more intuitive.
  num_rows=$(grep -c "^" "$summary_file")
  [ "$num_rows" -eq "2" ] || die "Unexpected number of lines in '$summary_file'!"

  summary_data=$(awk '1' "$summary_file" | tail -n1)
  num_mutants_covered=$(echo "$summary_data" | cut -f2 -d',')
  num_mutants_killed=$(echo "$summary_data" | cut -f3 -d',')

  [ "$num_mutants_covered" -eq 0 ] || die "$num_mutants_covered mutants have been covered!"
  [ "$num_mutants_killed" -eq 0 ] || die "$num_mutants_killed mutants have been killed!"

  # TODO Would be nice to test the number of excluded mutants. In order to do it
  # Major has to write that number to the '$pid_bid_dir/summary.csv' file.

  # Clean up
  rm -rf "$pid_bid_dir"
}

_test_exclude_mutants_option || die "Test 'test_exclude_mutants_option' has failed!"

# EOF

