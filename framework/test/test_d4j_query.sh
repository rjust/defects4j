#!/usr/bin/env bash
################################################################################
#
# This script runs a set of basic queries against d4j-query and checks the results
#
################################################################################
source test.include

HERE=$(cd `dirname $0` && pwd)

$BASE_DIR/framework/bin/defects4j query -p Collections -h >> $HERE"/temp"
result=`diff $HERE/temp $HERE/resources/output/d4j-query/1`

[ "$result" == "" ] || die "query \"-p Collections\" -h failed: $result"

rm $HERE"/temp"

$BASE_DIR/framework/bin/defects4j query -p Collections >> $HERE"/temp"
result=`diff $HERE/temp $HERE/resources/output/d4j-query/2`

[ "$result" == "" ] || die "query \"-p Collections\" failed: $result"

rm $HERE"/temp"

$BASE_DIR/framework/bin/defects4j query -p Collections -q "revision.buggy,classes.modified" >> $HERE"/temp"
result=`diff $HERE/temp $HERE/resources/output/d4j-query/3`

[ "$result" == "" ] || die "query \"-p Collections -q \"revision.buggy,classes.modified\"\" failed: $result"

rm $HERE"/temp"

$BASE_DIR/framework/bin/defects4j query -p Collections -q "revision.buggy,classes.modified" -d >> $HERE"/temp"
result=`diff $HERE/temp $HERE/resources/output/d4j-query/4`

[ "$result" == "" ] || die "query \"-p Collections -q \"revision.buggy,classes.modified\" -d\" failed: $result"

rm $HERE"/temp"

$BASE_DIR/framework/bin/defects4j query -p Collections -q "revision.buggy,classes.modified" -a >> $HERE"/temp"
result=`diff $HERE/temp $HERE/resources/output/d4j-query/5`

[ "$result" == "" ] || die "query \"-p Collections -q \"revision.buggy,classes.modified\" -a\" failed: $result"

rm $HERE"/temp"

$BASE_DIR/framework/bin/defects4j query -p Collections -q "deprecated.reason" -a >> $HERE"/temp"
result=`diff $HERE/temp $HERE/resources/output/d4j-query/6`

[ "$result" == "" ] || die "query \"-p Collections -q \"deprecated.reason\" -a\" failed: $result"

rm $HERE"/temp"
