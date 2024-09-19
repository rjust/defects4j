#!/usr/bin/env bash
################################################################################
#
# This script tests the monitor.test command, which makes assumption about JVM
# behavior when run with -verbose:class.
#
################################################################################

HERE="$(cd "$(dirname "$0")" && pwd)" || { echo "cannot cd to $(dirname "$0")"; exit 2; }

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

pid=Codec
bid=18
vid=${bid}f
work_dir=$TMP_DIR/$pid-$vid

# Checkout buggy version
defects4j checkout -p $pid -v $vid -w "$work_dir" || die "checkout program version $pid-$vid"

actual="$(mktemp)"
expected="resources/monitor.test.expected"
# Compile buggy version
defects4j monitor.test -t org.apache.commons.codec.binary.HexTest -w "$work_dir" > "$actual" || die "compile program version $pid-$vid"

cmp "$actual" "$expected" || die "compare actual vs. expected output: $actual vs. $expected"
