#!/usr/bin/env bash

##### Additional repositories for Version 1.4

# The name of the archive that contains all project repos
ARCHIVE=defects4j-additional-repos-1.4.zip

clean() {
    rm -rf \
    commonscli.git \
    commonscodec.git \
    commonscsv.git \
    commonsjxpath.git \
    gson.git \
    guava.git \
    jacksoncore.git \
    jacksondatabind.git \
    jacksondataformatxml.git \
    jsoup.git
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
wget -N http://blankslatetech.com/downloads/$ARCHIVE
new=$($cmd)

# Exit if no newer file is available
[ "$old" == "$new" ] && exit 0

# Remove old files
clean

# Extract new repos
unzip -q -u $ARCHIVE
