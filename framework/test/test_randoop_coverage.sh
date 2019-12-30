#!/bin/sh
################################################################################
#
# This script tests the test generation using Randoop, using the instructons at
# https://github.com/rjust/defects4j/blob/master/framework/test/README.md#randoop-coverage-on-the-defects4j-defects
#
################################################################################

# Fail if any comand fails.
set -e
# Show commands as they are run.
set -x

D4J_DIR=$PWD

### 1. Follow steps 1-4 under Steps to set up Defects4J in the top-level README.

## This is already done since we are in a clone of defects4j
# git clone https://github.com/rjust/defects4j
## Also already done
# cd defects4j

cpanm --installdeps .

./init.sh

export PATH=$PATH:$D4J_DIR/framework/bin

defects4j info -p Lang

# TODO
### 2. Optionally, indicate where to find the version of Randoop you wish to test.
### 
### export TESTGEN_LIB_DIR="path2directory-containing-randoop-current.jar"
### The randoop.jar you wish to test must be named randoop-current.jar. By default, the system runs version 4.0.4 of Randoop, located at "path2defects4j"/framework/lib/test_generation/generation/randooop-current.jar. If you change the default version of randoop-current.jar you must also copy the matching version of replacecall.jar to replacecall-current.jar in the same location as randoop-current.jar.

### 3. Run the test generation and coverage analysis:
# TODO: Currently, this does not generate tests for all the defects, just five in each project.
cd $D4J_DIR/framework/test
./randoop_coverage.sh

../util/show_coverage.pl
