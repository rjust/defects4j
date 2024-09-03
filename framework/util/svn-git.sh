#!/bin/sh
#
# This script updates, for the Chart project:
# * active-bugs.csv
# * dir-layout.csv
# * commit-db
#
# For each file, it replaces svn revision ids with git commit hashes,
# corresponding to its current git repo on GitHub.
#
# This script is not intended for long-term archival, but rather to document the
# update process.
#
# This script writes the updated csv files to the D4J root directory.
#
# This script requires:
# * Defects4J to be installed and initialized
# * D4J_HOME to be set to the root directory of Defects4J
#
if [ -z ${D4J_HOME+x} ]; then
  echo "D4J_HOME not set!"
  exit 1
fi

# mktemp behavior is different on Linux and OSX
tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'd4j')

pushd ${tmp_dir} > /dev/null

${D4J_HOME}/framework/bin/defects4j checkout -p Chart -v 1f -w Chart-1f

# Full git history of the JFreeChart git repo on GH
git clone https://github.com/jfree/jfreechart
git --git-dir=jfreechart/.git log | tr -d '[:blank:]' > git.log

# Retain the csv header for active-bugs.csv
head -1 ${D4J_HOME}/framework/projects/Chart/active-bugs.csv > ${tmp_dir}/active-bugs.csv

# Find git commit hashes for each bug in active-bugs.csv
tail -n+2 ${D4J_HOME}/framework/projects/Chart/active-bugs.csv |\
while read line; do
  bid=$(echo $line | cut -f1 -d',')
  svn_buggy=$(echo $line | cut -f2 -d',')
  svn_fixed=$(echo $line | cut -f3 -d',')
  metadata=$(echo $line | cut -f4,5 -d',')

  # Just in case the svn revision ids for a bug cannot be mapped to git
  git_buggy=""
  git_fixed=""

  # Get the svn commit message and find the corresponding commit in git.
  pushd Chart-1f > /dev/null
  svn log -r $svn_fixed | tail -n+4 | grep -v "\---" > ${tmp_dir}/${bid}.svn
  popd > /dev/null
  svn_first_line="$(head -1 ${bid}.svn | tr -d '[:blank:]')"

  # The first line may match multiple commits -> evaluate all candidate commits
  commits=$(grep -B4 "${svn_first_line}" git.log | grep "commit" | sed -e 's/commit\s*//g')
  echo $bid
  for c in $commits; do
    echo "$c -- $(git --git-dir=jfreechart/.git diff $c $c~1 | wc -l)"
    git --git-dir=jfreechart/.git log -n1 $c | tail -n+5 >  ${bid}.git
    # We found a match if the messages are identical, modulo whitespace changes
    # Multiple commits may match -> pick the last, which is the oldest commit
    if git diff -w --ignore-blank-lines --quiet ${bid}.svn ${bid}.git; then
      git_fixed="$c"
    fi
  done
  echo

  # These bugs are no longer reproducible after the SVN -> Git conversion
  if [ "$bid" -ge 4 ] && [ "$bid" -le 10 ]; then
    continue
  fi
  if [ "$bid" -eq 26 ]; then
    continue
  fi

  # Update failing-tests file names
  if [ ! -z "${git_fixed}" ]; then
    # The buggy commit is the parent commit
    git_buggy=$(git --git-dir=${tmp_dir}/jfreechart/.git rev-list --parents -n 1 ${git_fixed} | cut -f2 -d' ')
    # Update failing_tests file names, if needed
    pushd ${D4J_HOME}/framework/projects/Chart/failing_tests > /dev/null
    [ -e ${svn_fixed} ] && mv ${svn_fixed} ${git_fixed}
    [ -e ${svn_buggy} ] && mv ${svn_buggy} ${git_buggy}
    popd > /dev/null
  fi
  # Output the entry for active-bugs.csv
  echo "${bid},${git_buggy},${git_fixed},${metadata}" >> ${tmp_dir}/active-bugs.csv
  # Output the entires for dir-layout.csv (identical layout for all revisions)
  echo "${git_fixed},source,tests" >> ${tmp_dir}/dir-layout.csv
  echo "${git_buggy},source,tests" >> ${tmp_dir}/dir-layout.csv
done

popd > /dev/null

# Update the legacy commit-db file
tail -n+2 ${tmp_dir}/active-bugs.csv | sed -e's/UNKNOWN//g' > ${D4J_HOME}/framework/projects/Chart/commit-db

# Move project files
mv ${tmp_dir}/active-bugs.csv ${tmp_dir}/dir-layout.csv ${D4J_HOME}/framework/projects/Chart/

# Use Git as opposed to Svn in perl module
pushd ${D4J_HOME} > /dev/null
git apply ${D4J_HOME}/framework/util/Chart.diff
popd > /dev/null

# Update patch file names
pushd ${D4J_HOME}/framework/projects/Chart/compile-errors > /dev/null
mv experimental-149-436.diff experimental-19-25.diff
rm experimental-491-494.diff
mv test-1025-1087.diff test-7-11.diff
mv test-2236-2272.diff test-1-2.diff
rm test-2270-2272.diff
rm test-778-784.diff
mv test-807-811.diff test-14-14.diff
popd > /dev/null

# Add new patch file for build.xml
cp build-1-4.diff ${D4J_HOME}/framework/projects/Chart/compile-errors

rm -rf ${tmp_dir}
