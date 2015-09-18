#!/usr/bin/env bash
################################################################################
#
# This script runs the sanity check on each project version.
#
################################################################################
# Import helper subroutines and variables, and init Defects4J
source test.include
init

for pid in Chart Closure Lang Math Time; do
    sanity_check.pl -p $pid || or die "run sanity check: $pid"
done
