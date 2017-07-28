#!/usr/bin/env bash
################################################################################
#
# This script tests the D4J's mutation analysis script.
#
################################################################################

HERE=$(cd `dirname $0` && pwd)

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

_test_exclude_mutants_option() {

  local pid="Lang" # any pid-bid should work
  local bid="1f"
  local pid_bid_dir="$TMP_DIR/$pid-$bid"
  rm -rf "$pid_bid_dir"

  # get project-version
  defects4j checkout -p "$pid" -v "$bid" -w "$pid_bid_dir" || die "It was not possible to checkout $pid-$bid to '$pid_bid_dir'!"

  ##
  # without excluding any mutant

  defects4j mutation -w "$pid_bid_dir" -r || die "Mutation-analysis of all mutants has failed!"

  # MutantsGenerated,MutantsCovered,MutantsKilled,MutantsLive,RuntimePreprocSeconds,RuntimeAnalysisSeconds
  local summary_file="$pid_bid_dir/summary.csv"
  [ -s "$summary_file" ] || die "There is not any '$summary_file' file or it is empty!"

  local num_rows=$(awk '1' "$summary_file" | wc -l | cut -f1 -d' ') # last row of 'summary.csv' does not have an end of line character
  [ "$num_rows" -eq "2" ] || die "'$summary_file' has no data!"

  local summary_data=$(awk '1' "$summary_file" | tail -n1)
  local num_mutants_covered=$(echo "$summary_data" | cut -f2 -d',')
  local num_mutants_killed=$(echo "$summary_data" | cut -f3 -d',')

  [ "$num_mutants_covered" -gt 0 ] || die "0 mutants covered!"
  [ "$num_mutants_killed" -gt 0 ] || die "0 mutants killed!"

#  # TODO Would be nice to test the number of excluded mutants. In order to do it
#  # Major has to write that number to the '$pid_bid_dir/summary.csv' file.

  >"$summary_file" # reset it, just in case

  ##
  # exclude all mutants

  local mutants_file="$pid_bid_dir/mutants.log"
  [ -s "$mutants_file" ] || die "There is not any '$mutants_file' file or it is empty!"

  local exclude_file="$pid_bid_dir/exclude_all_mutants.txt"
  cut -f1 -d':' "$mutants_file" > "$exclude_file"

  defects4j mutation -w "$pid_bid_dir" -r -e "$exclude_file" || die "Mutation-analysis of no mutant has failed!"

  num_rows=$(awk '1' "$summary_file" | wc -l | cut -f1 -d' ') # last row of 'summary.csv' does not have an end of line character
  [ "$num_rows" -eq "2" ] || die "'$summary_file' has no data!"

  summary_data=$(awk '1' "$summary_file" | tail -n1)
  num_mutants_covered=$(echo "$summary_data" | cut -f2 -d',')
  num_mutants_killed=$(echo "$summary_data" | cut -f3 -d',')

  [ "$num_mutants_covered" -eq 0 ] || die "$num_mutants_covered mutants have been covered!"
  [ "$num_mutants_killed" -eq 0 ] || die "$num_mutants_killed mutants have been killed!"

  # TODO Would be nice to test the number of excluded mutants. In order to do it
  # Major has to write that number to the '$pid_bid_dir/summary.csv' file.

  rm -rf "$pid_bid_dir"
}

_test_exclude_mutants_option || die "Test 'test_exclude_mutants_option' has failed!"

# EOF

