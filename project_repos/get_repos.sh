#!/usr/bin/env bash

function clean {
    rm -rf \
    closure-compiler.git \
    commons-lang.git \
    commons-math.git \
    jfreechart \
    joda-time.git \
    README 
}

# The BSD version of stat does not support --version or -c
stat --version &> /dev/null 
if [[ $? ]]; then
    # GNU version
    cmd="stat -c %Y defects4j-repos.zip"
else
    # BSD version
    cmd="stat -f %m defects4j-repos.zip"
fi

old=$($cmd)
# Only download repos if the server has a newer file
wget -N http://homes.cs.washington.edu/~rjust/defects4j/download/defects4j-repos.zip
new=$($cmd)

# Install additional repositories (separate from core defects4j)
./get_commonsjxpath.sh
./get_commonscsv.sh
./get_guava.sh
./get_jacksoncore.sh
./get_jacksondatabind.sh
./get_jacksonxml.sh
./get_jsoup.sh
./get_mockito.sh

# Exit if no newer file is available
[ "$old" == "$new" ] && exit 0

# Remove old files
clean

# Extract new repos
unzip -u defects4j-repos.zip && mv defects4j/project_repos/* . && rm -r defects4j
