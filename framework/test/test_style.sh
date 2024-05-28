#!/bin/sh

TOPLEVEL="$(git rev-parse --show-toplevel)"

cd "$TOPLEVEL" || (echo "Cannot cd to $TOPLEVEL" && exit 1)

# Check style of sh scripts.
grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)sh' --exclude=\*~ "$TOPLEVEL"/framework | while read -r line
do
    shellcheck -x -P SCRIPTDIR --format=gcc "$line"
    checkbashisms "$line"
done
#shellcheck disable=2043 # only one file in list
for file in "$TOPLEVEL"/lib/test_generation/bin/_tool.source ; do
    shellcheck -x -P SCRIPTDIR --format=gcc "$file"
    checkbashisms "$file"
done

# Check style of bash scripts.
grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)bash' --exclude=\*~ "$TOPLEVEL"/framework | while read -r line
do
    shellcheck -x -P SCRIPTDIR --format=gcc "$line"
done
#shellcheck disable=2043 # only one file in list
for file in "$TOPLEVEL"/init.sh ; do
    shellcheck -x -P SCRIPTDIR --format=gcc "$file"
    checkbashisms "$file"
done

