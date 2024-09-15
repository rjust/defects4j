#!/usr/bin/env bash
################################################################################
#
# This script runs the sanity check on each project version.
#
################################################################################

HERE="$(cd "$(dirname "$0")" && pwd)" || { echo "cannot cd to $(dirname "$0")"; exit 2; }

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

for pid in Chart Closure Lang Math Time; do
    sanity_check.pl -p $pid || or die "run sanity check: $pid"
done
