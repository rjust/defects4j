#!/usr/bin/env bash

set -e

# The name of the archive that contains all project repos
ARCHIVE=defects4j-repos-v3.zip

main() {
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
    download_url "https://defects4j.org/downloads/$ARCHIVE"

    new=$($cmd)

    # Exit if no newer file is available
    [ "$old" == "$new" ] && exit 0

    # Remove old files
    clean

    # Extract new repos
    unzip -q -u $ARCHIVE && mv defects4j/project_repos/* . && rm -r defects4j
}

clean() {
    rm -rf \
    closure-compiler.git \
    commons-cli.git \
    commons-codec.git \
    commons-collections.git \
    commons-compress.git \
    commons-csv.git \
    commons-jxpath.git \
    commons-lang.git \
    commons-math.git \
    gson.git \
    jackson-core.git \
    jackson-databind.git \
    jackson-dataformat-xml.git \
    jfreechart \
    jfreechart.git \
    joda-time.git \
    jsoup.git \
    mockito.git \
    defects4j-repos.zip \
    repos.csv \
    sync.sh \
    README 
}

# MacOS does not install the timeout command by default.
if [ "$(uname)" = "Darwin" ] ; then
  function timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }
fi

# Download the remote resource to a local file of the same name, if the
# remote resource is newer.  Works around connections that hang.  Takes a
# single command-line argument, a URL.
download_url() {
    BASENAME=`basename ${@: -1}`
    if [ "$(uname)" = "Darwin" ] ; then
        wget -nv -N "$@"
    else
	timeout 300 curl -s -S -R -L -O -z "$BASENAME" "$@" || (echo "retrying curl $@" && rm -f "$BASENAME" && curl -R -L -O -z "$BASENAME" "$@")
    fi
}

main
