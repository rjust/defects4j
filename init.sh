#!/usr/bin/env bash
#
################################################################################
# This script initializes Defects4J. In particular, it downloads and sets up:
# - the project's version control repositories
# - the Major mutation framework
# - the supported test generation tools
# - the supported code coverage tools (TODO)
################################################################################
# TODO: Major and the coverage tools should be moved to framework/lib

# Check whether wget is available
if ! wget --version > /dev/null 2>&1; then
    echo "Couldn't find wget to download dependencies. Please install wget and re-run this script."
    exit 1
fi

# Directories for project repositories and external libraries
BASE=$(cd $(dirname $0); pwd)
DIR_REPOS="$BASE/project_repos"
DIR_LIB_GEN="$BASE/framework/lib/test_generation/generation"
DIR_LIB_RT="$BASE/framework/lib/test_generation/runtime"
mkdir -p $DIR_LIB_GEN
mkdir -p $DIR_LIB_RT

#
# Download project repositories if necessary
#
cd $DIR_REPOS && ./get_repos.sh

#
# Download Major
#
MAJOR_VERSION="1.1.7"
MAJOR_URL="http://mutation-testing.org/downloads"
MAJOR_ZIP="major-${MAJOR_VERSION}_jre7.zip"
cd $BASE && wget -N $MAJOR_URL/$MAJOR_ZIP \
         && unzip -o $MAJOR_ZIP \
         && rm $MAJOR_ZIP
# Increase memory for Closure; set headless mode.
launcher=$(sed -e 's/ReservedCodeCacheSize=128M/ReservedCodeCacheSize=256M/' $BASE/major/bin/ant \
         | sed -e 's/MaxPermSize=256M/MaxPermSize=1G \\\
    -Djava.awt.headless=true/')
echo "$launcher" > "$BASE/major/bin/ant"

#
# Download EvoSuite
#
EVOSUITE_VERSION="1.0.2"
#EVOSUITE_URL="http://www.evosuite.org/files"
EVOSUITE_URL="https://github.com/EvoSuite/evosuite/releases/download/v${EVOSUITE_VERSION}"
EVOSUITE_JAR="evosuite-${EVOSUITE_VERSION}.jar"
EVOSUITE_RT_JAR="evosuite-standalone-runtime-${EVOSUITE_VERSION}.jar"
cd $DIR_LIB_GEN && [ ! -f $EVOSUITE_JAR ] \
                && wget $EVOSUITE_URL/$EVOSUITE_JAR \
                && ln -sf $EVOSUITE_JAR evosuite-current.jar 
cd $DIR_LIB_RT  && [ ! -f $EVOSUITE_RT_JAR ] \
                && wget $EVOSUITE_URL/$EVOSUITE_RT_JAR \
                && ln -sf $EVOSUITE_RT_JAR evosuite-rt.jar 

#
# Download Randoop
#
RANDOOP_VERSION="2.1.0"
RANDOOP_URL="https://github.com/randoop/randoop/releases/download/v${RANDOOP_VERSION}"
RANDOOP_JAR="randoop-${RANDOOP_VERSION}.jar"
cd $DIR_LIB_GEN && [ ! -f $RANDOOP_JAR ] \
                && wget $RANDOOP_URL/$RANDOOP_JAR \
                && ln -sf $RANDOOP_JAR randoop-current.jar

echo
echo "Defects4J successfully initialized."
