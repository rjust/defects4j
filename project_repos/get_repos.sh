#!/usr/bin/env bash

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

# Only download repos if the server has a newer file
wget -N http://people.cs.umass.edu/~rjust/defects4j/download/$ARCHIVE

# Remove old files
clean

# Extract new repos
unzip -q -u $ARCHIVE && mv defects4j/project_repos/* . && rm -r defects4j
