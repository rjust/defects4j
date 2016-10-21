#!/bin/sh
# $1 = working directory
# $2 = location of Defects4J (D4J_HOME)

WORK_DIR=$1
D4J_HOME=$2

BUILD_FILE="build.gradle"

echo >> $WORK_DIR/$BUILD_FILE
echo "compileJava.options.fork = true" >> $WORK_DIR/$BUILD_FILE
echo "compileJava.options.forkOptions.executable = '$D4J_HOME/major/bin/major'" >> $WORK_DIR/$BUILD_FILE
