#!/usr/bin/env bash

function clean {
    rm -rf jacksondataformatxml.git 
}

# The BSD version of stat does not support --version or -c
stat --version &> /dev/null 
if [[ $? ]]; then
    # GNU version
    cmd="stat -c %Y jacksondataformatxml.zip"
else
    # BSD version
    cmd="stat -f %m jacksondataformatxml.zip"
fi

old=$($cmd)
# Only download repos if the server has a newer file
wget -N http://greggay.com/data/jacksonxml/jacksondataformatxml.zip
new=$($cmd)

# Exit if no newer file is available
[ "$old" == "$new" ] && exit 0

# Remove old files
clean

# Extract new repos
unzip -u jacksondataformatxml.zip
