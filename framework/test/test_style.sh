#!/bin/sh

TOPLEVEL="$(git rev-parse --show-toplevel)"

cd "$TOPLEVEL" || (echo "Cannot cd to $TOPLEVEL" && exit 1)

find . \( -name '*.pm' -o -name '*.pl' \) -print0 | xargs -0 -n1 perl -Mstrict -Mdiagnostics -cw

# Check style of sh scripts.
grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)sh' --exclude=\*~ "$TOPLEVEL"/framework | while read -r line
do
    shellcheck -x -P SCRIPTDIR --format=gcc "$line"
    checkbashisms "$line"
done

# Check style of bash scripts.
grep -r -l '^\#! \?\(/bin/\|/usr/bin/env \)bash' --exclude=\*~ "$TOPLEVEL"/framework | while read -r line
do
    shellcheck -x -P SCRIPTDIR --format=gcc "$line"
done
for file in "$TOPLEVEL"/init.sh "$TOPLEVEL"/framework/lib/test_generation/bin/_tool.source ; do
    shellcheck -x -P SCRIPTDIR --format=gcc "$file"
done
