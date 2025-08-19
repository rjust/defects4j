#!/usr/bin/env bash
################################################################################
#
# This script tests whether Defects4J correctly parses and interprets the four
# possible versions (f, b, b.min, b.orig) for two bugs of each project.
#
################################################################################
# Import helper subroutines and variables, and init Defects4J
source test.include
init

################################################################################
test_vids() {
  local pid=$1 
  local bid=$2 

  local work_dir=$TMP_DIR/$pid-$bid
  # Test the buggy version
  for type in f b b.min b.orig; do
    local vid=${bid}${type}
    # Checkout buggy version
    defects4j checkout -p $pid -v $vid -w $work_dir || die "checkout program version $pid-$vid"
  
    # Verify that defects4j's config file exists 
    [ -e $work_dir/.defects4j.config ] || die "read config file"
    # Verify that defects4j's config file provides the correct data
    grep -q "pid=$pid" $work_dir/.defects4j.config || die "verify pid in config file"
    grep -q "vid=$vid" $work_dir/.defects4j.config || die "verify vid in config file"
  done

  # Diff between <bid>b.min and <bid>b
  # -> only .defects4j.config must change
  defects4j checkout -p $pid -v ${bid}b.min -w $work_dir 
  cd $work_dir && git diff D4J_${pid}_${bid}_BUGGY_VERSION | diffstat -t > $work_dir/diff.stats
  num=$(cat $work_dir/diff.stats | wc -l)
  [ $num -eq 2 ] || die "verify changed files between ${pid}-${bid}b.min and ${pid}-${bid}b"
  grep -q "^1,1,0,.defects4j.config" $work_dir/diff.stats || die "verify diff between ${pid}-${bid}b.min and ${pid}-${bid}b"

  # Diff between <bid>b.orig and <bid>f
  # -> same changes as diff between pre-fix and post-fix revisions -- source path only)
  tag_1=D4J_${pid}_${bid}_PRE_FIX_REVISION
  tag_2=D4J_${pid}_${bid}_POST_FIX_REVISION
  rev_f=$(grep "^$bid," $BASE_DIR/framework/projects/$pid/commit-db | cut -f3 -d',')
  src_dir=$(grep "^${rev_f}," $BASE_DIR/framework/projects/$pid/dir-layout.csv | cut -f2 -d',')

  defects4j checkout -p $pid -v ${bid}b.orig -w $work_dir 
  (cd $work_dir && git diff D4J_${pid}_${bid}_FIXED_VERSION | filterdiff -x '*/.defects4j.config' | diffstat -t > $work_dir/diff.1.stats)
  # Special case for older versions of JodaTime
  if [ "$pid" == "Time" ] && git cat-file -e $tag_1:JodaTime 2>/dev/null; then
    (cd $work_dir && git diff ${tag_2} ${tag_1} -- "JodaTime/$src_dir" | diffstat -t > $work_dir/diff.2.stats)
  else
    (cd $work_dir && git diff ${tag_2} ${tag_1} -- $src_dir | diffstat -t > $work_dir/diff.2.stats)
  fi
  perl -E "print '-' x 75, \"\\n\""
  cat $work_dir/diff.*.stats
  perl -E "print '-' x 75, \"\\n\""
  cmp -s $work_dir/diff.1.stats $work_dir/diff.2.stats || die "verify changed files between ${pid}-${bid}b.orig and ${pid}-${bid}f"

  # Run the tests on the original buggy version and verify triggering tests
  # Mockito require an explicit call to compile before calling test
  defects4j compile -w $work_dir
  defects4j test -r -w $work_dir
  triggers=$(num_triggers "$work_dir/failing_tests")
  expected=$(num_triggers "$BASE_DIR/framework/projects/$pid/trigger_tests/$bid")
  [ $triggers -eq $expected ] \
          || die "verify number of triggering tests: $pid-$vid (expected: $expected, actual: $triggers)"
  for t in $(get_triggers "$BASE_DIR/framework/projects/$pid/trigger_tests/$bid"); do
      grep -q "$t" "$work_dir/failing_tests" || die "expected triggering test $t did not fail"
  done
}
################################################################################

PROJECTS_DIR=$BASE_DIR/framework/projects

# Test first and last bug in each project
for pid in $(get_project_ids); do
  ids=$(get_bug_ids $PROJECTS_DIR/$pid/commit-db)
  bug_1=$(echo $ids | cut -f1 -d" ")
  bug_n=$(echo $ids | rev | cut -f1 -d" " | rev)
  test_vids $pid $bug_1 && test_vids $pid $bug_n
done
