#!/usr/bin/env bash
################################################################################
#
# This script runs a set of basic queries against d4j-query and checks the results
#
################################################################################

HERE="$(cd "$(dirname "$0")" && pwd)" || { echo "cannot cd to $(dirname "$0")"; exit 2; }

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

"$BASE_DIR"/framework/bin/defects4j query -p Collections -H >> "$HERE"/temp
result=$(diff "$HERE"/temp "$HERE"/resources/output/d4j-query/1)

[ "$result" == "" ] || die "query \"-p Collections\" -H failed: $result"

rm "$HERE"/temp

"$BASE_DIR"/framework/bin/defects4j query -p Collections >> "$HERE"/temp
result=$(diff "$HERE"/temp "$HERE"/resources/output/d4j-query/2)

[ "$result" == "" ] || die "query \"-p Collections\" failed: $result"

rm "$HERE"/temp

"$BASE_DIR"/framework/bin/defects4j query -p Collections -q "revision.id.buggy,classes.modified" >> "$HERE"/temp
result=$(diff "$HERE"/temp "$HERE"/resources/output/d4j-query/3)

[ "$result" == "" ] || die "query \"-p Collections -q \"revision.id.buggy,classes.modified\"\" failed: $result"

rm "$HERE"/temp

"$BASE_DIR"/framework/bin/defects4j query -p Collections -q "revision.id.buggy,classes.modified" -D >> "$HERE"/temp
result=$(diff "$HERE"/temp "$HERE"/resources/output/d4j-query/4)

[ "$result" == "" ] || die "query \"-p Collections -q \"revision.id.buggy,classes.modified\" -D\" failed: $result"

rm "$HERE"/temp

"$BASE_DIR"/framework/bin/defects4j query -p Collections -q "revision.id.buggy,classes.modified" -A >> "$HERE"/temp
result=$(diff "$HERE"/temp "$HERE"/resources/output/d4j-query/5)

[ "$result" == "" ] || die "query \"-p Collections -q \"revision.id.buggy,classes.modified\" -A\" failed: $result"

rm "$HERE"/temp

"$BASE_DIR"/framework/bin/defects4j query -p Collections -q "deprecated.reason" -A >> "$HERE"/temp
result=$(diff "$HERE"/temp "$HERE"/resources/output/d4j-query/6)

[ "$result" == "" ] || die "query \"-p Collections -q \"deprecated.reason\" -A\" failed: $result"

rm "$HERE"/temp
