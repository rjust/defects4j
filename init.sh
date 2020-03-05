#!/usr/bin/env bash
#
# Any subsequent command which fail will cause the shell script to exit
# immediately
set -e
#
################################################################################
# This script initializes Defects4J. In particular, it downloads and sets up:
# - the project's version control repositories
# - the Major mutation framework
# - the supported test generation tools
# - the supported code coverage tools (TODO)
################################################################################
# TODO: Major and the coverage tools should be moved to framework/lib

# Check whether curl is available
if [ "$(uname)" = "Darwin" ] ; then
    if ! wget --version > /dev/null 2>&1; then
        echo "Couldn't find wget to download dependencies. Please install wget and re-run this script."
        exit 1
    fi
fi
if ! curl --version > /dev/null 2>&1; then
    echo "Couldn't find curl to download dependencies. Please install curl and re-run this script."
    exit 1
fi

HOST_URL="https://defects4j.org/downloads"

# Directories for project repositories and external libraries
BASE="$(cd $(dirname $0); pwd)"
DIR_REPOS="$BASE/project_repos"
DIR_LIB_GEN="$BASE/framework/lib/test_generation/generation"
DIR_LIB_RT="$BASE/framework/lib/test_generation/runtime"
DIR_LIB_GRADLE="$BASE/framework/lib/build_systems/gradle"
mkdir -p "$DIR_LIB_GEN" && mkdir -p "$DIR_LIB_RT" && mkdir -p "$DIR_LIB_GRADLE"

################################################################################
#
# Utility functions
#

# MacOS does not install the timeout command by default.
if [ "$(uname)" = "Darwin" ] ; then
  function timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }
fi

# Download the remote resource to a local file of the same name, if the
# remote resource is newer.  Works around connections that hang.  Takes a
# single command-line argument, a URL.
download_url() {
    echo "Downloading $@"
    if [ "$(uname)" = "Darwin" ] ; then
        wget -nv -N "$@"
    else
	BASENAME=`basename ${@: -1}`
	if [ -f $BASENAME ]; then
	    ZBASENAME="-z $BASENAME"
	else
	    ZBASENAME=""
	fi
	timeout 300 curl -s -S -R -L -O $ZBASENAME "$@" || (echo "retrying curl $@" && rm -f "$BASENAME" && curl -R -L -O "$@")
    fi
    echo "Downloaded $@"
}

# Get time of last data modification of a file
get_modification_timestamp() {
    local USAGE="Usage: get_modification_timestamp <file>"
    if [ "$#" != 1 ]; then
        echo "$USAGE" >&2
        exit 1
    fi

    local f="$1"

    # The BSD version of stat does not support --version or -c
    if stat --version &> /dev/null; then
        # GNU version
        cmd="stat -c %Y $f"
    else
        # BSD version
        cmd="stat -f %m $f"
    fi

    local ts=$($cmd)
    echo "$ts"
}

################################################################################
#
# Download project repositories if necessary
#
echo "Setting up project repositories ... "
cd "$DIR_REPOS" && ./get_repos.sh

################################################################################
#
# Download Major
#
echo
echo "Setting up Major ... "
MAJOR_VERSION="1.3.4"
MAJOR_URL="https://mutation-testing.org/downloads"
MAJOR_ZIP="major-${MAJOR_VERSION}_jre7.zip"
cd "$BASE" && download_url "$MAJOR_URL/$MAJOR_ZIP" \
           && unzip -o "$MAJOR_ZIP" > /dev/null \
           && rm "$MAJOR_ZIP" \
           && cp major/bin/.ant major/bin/ant

################################################################################
#
# Download EvoSuite
#
echo
echo "Setting up EvoSuite ... "
EVOSUITE_VERSION="1.0.6"
EVOSUITE_URL="https://github.com/EvoSuite/evosuite/releases/download/v${EVOSUITE_VERSION}"
EVOSUITE_JAR="evosuite-${EVOSUITE_VERSION}.jar"
EVOSUITE_RT_JAR="evosuite-standalone-runtime-${EVOSUITE_VERSION}.jar"
cd "$DIR_LIB_GEN" && download_url "$EVOSUITE_URL/$EVOSUITE_JAR"
cd "$DIR_LIB_RT"  && download_url "$EVOSUITE_URL/$EVOSUITE_RT_JAR"
# Set symlinks for the supported version of EvoSuite
(cd "$DIR_LIB_GEN" && ln -sf "$EVOSUITE_JAR" "evosuite-current.jar")
(cd "$DIR_LIB_RT" && ln -sf "$EVOSUITE_RT_JAR" "evosuite-rt.jar")

################################################################################
#
# Download Randoop
#
echo
echo "Setting up Randoop ... "
RANDOOP_VERSION="4.2.2"
RANDOOP_URL="https://github.com/randoop/randoop/releases/download/v${RANDOOP_VERSION}"
RANDOOP_ZIP="randoop-${RANDOOP_VERSION}.zip"
RANDOOP_JAR="randoop-all-${RANDOOP_VERSION}.jar"
REPLACECALL_JAR="replacecall-${RANDOOP_VERSION}.jar"
COVEREDCLASS_JAR="covered-class-${RANDOOP_VERSION}.jar"
(cd "$DIR_LIB_GEN" && download_url "$RANDOOP_URL/$RANDOOP_ZIP" \
                   && unzip -q $RANDOOP_ZIP)
# Set symlink for the supported version of Randoop
(cd "$DIR_LIB_GEN" && ln -sf "randoop-${RANDOOP_VERSION}/$RANDOOP_JAR" "randoop-current.jar")
(cd "$DIR_LIB_GEN" && ln -sf "randoop-${RANDOOP_VERSION}/$REPLACECALL_JAR" "replacecall-current.jar")
(cd "$DIR_LIB_GEN" && ln -sf "randoop-${RANDOOP_VERSION}/$COVEREDCLASS_JAR" "covered-class-current.jar")

################################################################################
#
# Download build system dependencies
#
echo
echo "Setting up Gradle dependencies ... "

cd "$DIR_LIB_GRADLE"

GRADLE_DISTS_ZIP=defects4j-gradle-dists.zip
GRADLE_DEPS_ZIP=defects4j-gradle-deps.zip

old_dists_ts=0
old_deps_ts=0

if [ -e $GRADLE_DISTS_ZIP ]; then
    old_dists_ts=$(get_modification_timestamp $GRADLE_DISTS_ZIP)
fi
if [ -e $GRADLE_DEPS_ZIP ]; then
    old_deps_ts=$(get_modification_timestamp $GRADLE_DEPS_ZIP)
fi

# Only download archive if the server has a newer file
download_url $HOST_URL/$GRADLE_DISTS_ZIP
download_url $HOST_URL/$GRADLE_DEPS_ZIP
new_dists_ts=$(get_modification_timestamp $GRADLE_DISTS_ZIP)
new_deps_ts=$(get_modification_timestamp $GRADLE_DEPS_ZIP)

# Update gradle distributions/dependencies if a newer archive was available
[ "$old_dists_ts" != "$new_dists_ts" ] && mkdir "dists" && unzip -q -u $GRADLE_DISTS_ZIP -d "dists"
[ "$old_deps_ts" != "$new_deps_ts" ] && unzip -q -u $GRADLE_DEPS_ZIP

cd "$BASE"

################################################################################
#
# Download utility programs
#
echo
echo "Setting up utility programs ... "

BUILD_ANALYZER_VERSION="0.0.1"
BUILD_ANALYZER_JAR=build-analyzer-$BUILD_ANALYZER_VERSION.jar
BUILD_ANALYZER_URL="https://github.com/jose/build-analyzer/releases/download/v$BUILD_ANALYZER_VERSION/$BUILD_ANALYZER_JAR"
BUILD_ANALYZER_JAR_LOCAL="analyzer.jar"
cd "$BASE/framework/lib" && download_url "$BUILD_ANALYZER_URL"
rm -f "$BUILD_ANALYZER_JAR_LOCAL"
ln -s "$BUILD_ANALYZER_JAR" "$BUILD_ANALYZER_JAR_LOCAL"

echo
echo "Defects4J successfully initialized."
