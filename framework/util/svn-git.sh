#!/bin/sh
# This script updates the active-bugs.csv and dir-layout.csv files for Chart,
# replacing svn revision ids with git commit hashes, corresponding to its
# current git repo on GitHub.
#
# This script is not intended for long-term archival, but rather to document the
# update process.
#
# This script writes the updated csv files to the D4J root directory.
#
# This script requires:
# * Defects4J to be installed and initialized
# * D4J_HOME to be set to the root directory of Defects4J

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
head -1 ${D4J_HOME}/framework/projects/Chart/active-bugs.csv > ${D4J_HOME}/active-bugs.csv

# No header in dir-layout.csv
> ${D4J_HOME}/dir-layout.csv

# Find git commit hashes for each bug in active-bugs.csv
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
  for c in $commits; do
    git --git-dir=jfreechart/.git log -n1 $c | tail -n+5 >  ${bid}.git
    # We found a match if the messages are identical, modulo whitespace changes
    # Multiple commits may match -> pick the last, which is the oldest commit
    if git diff -w --ignore-blank-lines --quiet ${bid}.svn ${bid}.git; then
      git_fixed="$c"
    fi
  done
  if [ ! -z "${git_fixed}" ]; then
    # The buggy commit is the parent commit
    git_buggy=$(git --git-dir=${tmp_dir}/jfreechart/.git rev-list --parents -n 1 ${git_fixed} | cut -f2 -d' ')
  fi
  # Output the entry for active-bugs.csv
  echo "${bid},${git_buggy},${git_fixed},${metadata}" >> ${D4J_HOME}/active-bugs.csv
  # Output the entires for dir-layout.csv (identical layout for all revisions)
  echo "${git_fixed},source,tests" >> ${D4J_HOME}/dir-layout.csv
  echo "${git_buggy},source,tests" >> ${D4J_HOME}/dir-layout.csv
done < <(tail -n+2 ${D4J_HOME}/framework/projects/Chart/active-bugs.csv)

popd > /dev/null

rm -rf ${tmp_dir}
