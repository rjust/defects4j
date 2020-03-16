#!/bin/sh
################################################################################
#
# This script tests the test generation using Randoop, using the instructons at
# https://github.com/rjust/defects4j/blob/master/framework/test/README.md#randoop-coverage-on-the-defects4j-defects
# Any arguments to this script are passed through to the `randoop_coverage.sh` script.
#
################################################################################

# Fail if any comand fails.
set -e
# Show commands as they are run.
set -x

D4J_DIR=$PWD
echo "D4J_DIR=$PWD"

### 1. Follow steps 1-4 under Steps to set up Defects4J in the top-level README.

## This is already done since we are in a clone of defects4j
# git clone https://github.com/rjust/defects4j
## Also already done
# cd defects4j

cpanm --installdeps .

./init.sh

export PATH=$PATH:$D4J_DIR/framework/bin

defects4j info -p Lang

### 2. Use an appropirate version of Randoop:  a branch corresponding to your
### Defects4J branch if it exists, or by default the HEAD version from GitHub.
if [ -d "/tmp/plume-scripts" ] ; then
  git -C /tmp/plume-scripts pull -q > /dev/null 2>&1
else
  git -C /tmp clone --depth 1 -q https://github.com/plume-lib/plume-scripts.git
fi
/tmp/plume-scripts/git-clone-related randoop randoop /tmp/randoop
(cd /tmp/randoop && ./gradlew assemble)
(cd "$D4J_DIR/framework/lib/test_generation/generation" && /tmp/randoop/scripts/replace-randoop-jars.sh "-current")

### 3. Run the test generation and coverage analysis:
# TODO: Currently, this does not generate tests for all the defects, just five in each project.
cd "$D4J_DIR/framework/test"
./randoop_coverage.sh "$@"
