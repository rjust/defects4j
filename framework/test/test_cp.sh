#!/usr/bin/env bash
################################################################################
#
# This script validates the exported classpath of each bug.
#
################################################################################

HERE=$(cd `dirname $0` && pwd)

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

# Check arguments
while getopts ":p:" opt; do
  case $opt in
    p)
      PIDS="$PIDS $OPTARG"
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

main() {
  # If no pid is provided, iterate over all projects
  if [ "$PIDS" == "" ]; then
    PIDS=$(defects4j pids)
  fi

  TMP_ROOT=$(mktemp -d)
  ERROR=0

  echo "Temporary directory: $TMP_ROOT" >"$LOG"

  for PID in $PIDS; do
    for BID in $(defects4j bids -p $PID); do
      DIR="$TMP_ROOT/$PID-$BID"
      defects4j checkout -p $PID -v${BID}f -w "$DIR"
      defects4j compile -w "$DIR"
      echo "$PID-$BID: start" >> "$LOG"
      for cp in "cp.compile" "cp.test"; do
        key="$PID-$BID-$cp"
        echo "  - $key: $(defects4j export -p $cp -w "$DIR")" >> "$LOG"
        check_cp_entries $key $(defects4j export -p $cp -w "$DIR") || ERROR=1
      done
      echo "$PID-$BID: done" >> "$LOG"
    done
  done

  rm -rf $TMP_ROOT

  exit $ERROR
}

# Print usage message and exit
usage() {
    local known_pids=$(defects4j pids)
    echo "usage: $0 -p <project id>"
    echo "Project ids:"
    for pid in $known_pids; do
        echo "  * $pid"
    done
    exit 1
}

# Check all entries in a colon-separated classpath
check_cp_entries() {
  local KEY=$1
  local CP=$2
  for entry in $(echo $CP | tr ':' '\n'); do
    [[ -e "$entry" ]] || echo "!!! Invalid CP entry ($KEY): $entry" >> "$LOG"
  done
}

main
