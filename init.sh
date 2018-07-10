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
BASE="$(cd $(dirname $0); pwd)"
DIR_REPOS="$BASE/project_repos"
DIR_LIB_GEN="$BASE/framework/lib/test_generation/generation"
DIR_LIB_RT="$BASE/framework/lib/test_generation/runtime"
DIR_LIB_GRADLE="$BASE/framework/lib/build_systems/gradle"
DIR_LIB_FL="$BASE/framework/lib/fault_localization"
mkdir -p "$DIR_LIB_GEN" && mkdir -p "$DIR_LIB_RT" && mkdir -p "$DIR_LIB_GRADLE" && mkdir -p "$DIR_LIB_FL"

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
MAJOR_VERSION="1.3.2"
MAJOR_URL="http://mutation-testing.org/downloads"
MAJOR_ZIP="major-${MAJOR_VERSION}_jre7.zip"
cd "$BASE" && wget -nv -N "$MAJOR_URL/$MAJOR_ZIP" \
           && unzip -o "$MAJOR_ZIP" > /dev/null \
           && rm "$MAJOR_ZIP" \
           && cp major/bin/.ant major/bin/ant

################################################################################
#
# Download EvoSuite
#
echo
echo "Setting up EvoSuite ... "
EVOSUITE_VERSION="0.2.0"
EVOSUITE_URL="http://people.cs.umass.edu/~rjust/defects4j/download"
EVOSUITE_JAR="evosuite-${EVOSUITE_VERSION}.jar"
EVOSUITE_RT_JAR="evosuite-standalone-runtime-${EVOSUITE_VERSION}.jar"
cd "$DIR_LIB_GEN" && [ ! -f "$EVOSUITE_JAR" ] \
                  && wget -nv "$EVOSUITE_URL/$EVOSUITE_JAR"
cd "$DIR_LIB_RT"  && [ ! -f "$EVOSUITE_RT_JAR" ] \
                  && wget -nv "$EVOSUITE_URL/$EVOSUITE_RT_JAR"
# Set symlinks for the supported version of EvoSuite
(cd "$DIR_LIB_GEN" && ln -sf "$EVOSUITE_JAR" "evosuite-current.jar")
(cd "$DIR_LIB_RT" && ln -sf "$EVOSUITE_RT_JAR" "evosuite-rt.jar")

################################################################################
#
# Download Randoop
#
echo
echo "Setting up Randoop ... "
RANDOOP_VERSION="4.0.4"
RANDOOP_URL="https://github.com/randoop/randoop/releases/download/v${RANDOOP_VERSION}"
RANDOOP_JAR="randoop-all-${RANDOOP_VERSION}.jar"
REPLACECALL_JAR="replacecall-${RANDOOP_VERSION}.jar"
cd "$DIR_LIB_GEN" && [ ! -f "$RANDOOP_JAR" ] \
                  && wget -nv "$RANDOOP_URL/$RANDOOP_JAR"
cd "$DIR_LIB_GEN" && [ ! -f "$REPLACECALL_JAR" ] \
                  && wget -nv "$RANDOOP_URL/$REPLACECALL_JAR"
# Set symlink for the supported version of Randoop
(cd "$DIR_LIB_GEN" && ln -sf "$RANDOOP_JAR" "randoop-current.jar")
(cd "$DIR_LIB_GEN" && ln -sf "$REPLACECALL_JAR" "replacecall-current.jar")
(cd "$DIR_LIB_GEN" && jar -xf "$REPLACECALL_JAR" "default-replacements.txt")

################################################################################
#
# Download GZoltar and other utility program(s) for fault localization
#
echo
echo "Setting up GZoltar and utility program(s) for fault localization ... "
GZOLTAR_VERSION="1.7.0"
GZOLTAR_FULL_VERSION="${GZOLTAR_VERSION}.201807090550"
GZOLTAR_URL="https://github.com/GZoltar/gzoltar/releases/download/v${GZOLTAR_VERSION}"
GZOLTAR_ZIP="gzoltar-${GZOLTAR_FULL_VERSION}.zip"
GZOLTAR_TMP_DIR="gzoltar_tmp_dir"
GZOLTAR_ANT_JAR="gzoltarant.jar"
GZOLTAR_AGENT_RT_JAR="gzoltaragent.jar"

cd "$DIR_LIB_FL" && [ ! -f "$GZOLTAR_ZIP" ] \
                 && wget -nv "$GZOLTAR_URL/$GZOLTAR_ZIP" \
                 && unzip -o -q "$GZOLTAR_ZIP" -d "$GZOLTAR_TMP_DIR" \
                 && mv "$GZOLTAR_TMP_DIR/lib/$GZOLTAR_ANT_JAR" . \
                 && mv "$GZOLTAR_TMP_DIR/lib/$GZOLTAR_AGENT_RT_JAR" . \
                 && rm -r "$GZOLTAR_TMP_DIR" "$GZOLTAR_ZIP"

# Set symlinks for the supported version of GZoltar
(cd "$DIR_LIB_FL" && ln -sf "$GZOLTAR_ANT_JAR" "gzoltar-ant-current.jar")
(cd "$DIR_LIB_FL" && ln -sf "$GZOLTAR_AGENT_RT_JAR" "gzoltar-agent-rt-current.jar")

LOCS_TO_STMS_VERSION="0.0.1"
LOCS_TO_STMS_URL="https://github.com/GZoltar/locs-to-stms/releases/download/v${LOCS_TO_STMS_VERSION}"
LOCS_TO_STMS_JAR="locs-to-stms-${LOCS_TO_STMS_VERSION}-jar-with-dependencies.jar"

cd "$DIR_LIB_FL" && [ ! -f "$LOCS_TO_STMS_JAR" ] \
                 && wget -nv "$LOCS_TO_STMS_URL/$LOCS_TO_STMS_JAR"
(cd "$DIR_LIB_FL" && ln -sf "$LOCS_TO_STMS_JAR" "locs-to-stms-current.jar")

################################################################################
#
# Download build system dependencies
#
echo
echo "Setting up Gradle dependencies ... "
GRADLE_ZIP=defects4j-gradle.zip
# The BSD version of stat does not support --version or -c
if stat --version &> /dev/null; then
    # GNU version
    cmd="stat -c %Y $GRADLE_ZIP"
else
    # BSD version
    cmd="stat -f %m $GRADLE_ZIP"
fi

cd "$DIR_LIB_GRADLE"
if [ -e $GRADLE_ZIP ]; then
    old_ts=$($cmd)
else
    old_ts=0
fi
# Only download archive if the server has a newer file
wget -N http://people.cs.umass.edu/~rjust/defects4j/download/$GRADLE_ZIP
new=$($cmd)

# Update gradle versions if a newer archive was available
[ "$old" != "$new" ] && unzip -q -u $GRADLE_ZIP

cd "$BASE"
echo
echo "Defects4J successfully initialized."
