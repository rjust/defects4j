#!/usr/bin/env bash

set -e

# The name of the archive that contains all project repos
ARCHIVE=defects4j-repos.zip

clean() {
    rm -rf \
    closure-compiler.git \
    commons-lang.git \
    commons-math.git \
    jfreechart \
    joda-time.git \
    README 
}

# Try curl command twice to handle hosts that hang for a long time.
curl_with_retry() {
    timeout 5m curl -s -S "$@" || (echo "retrying curl $@" && curl "$@")
}

# The BSD version of stat does not support --version or -c
if stat --version &> /dev/null; then
    # GNU version
    cmd="stat -c %Y $ARCHIVE"
else
    # BSD version
    cmd="stat -f %m $ARCHIVE"
fi

if [ -e $ARCHIVE ]; then
    old=$($cmd)
else
    old=0
fi
# Only download repos if the server has a newer file
curl_with_retry -R -L -O -z "$ARCHIVE" "https://people.cs.umass.edu/~rjust/defects4j/download/$ARCHIVE"
new=$($cmd)

# Exit if no newer file is available
[ "$old" == "$new" ] && exit 0

# Remove old files
clean

# Extract new repos
unzip -q -u $ARCHIVE && mv defects4j/project_repos/* . && rm -r defects4j
