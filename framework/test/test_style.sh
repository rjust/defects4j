#!/bin/sh

TOPLEVEL="$(git rev-parse --show-toplevel)"

cd "$TOPLEVEL" || { echo "Cannot cd to $TOPLEVEL"; exit 2; }

# Check style of Perl scripts
find . \( -name '*.pm' -o -name '*.pl' \) -print0 | xargs -0 -n1 perl -Mstrict -Mdiagnostics -cw
grep -l --exclude-dir=project_repos --exclude=\*.pm --exclude=\*.pl --exclude=\*.sh --exclude=\*~ --exclude=template -r "=pod" . | while IFS= read -r file ; do
    perl -Mstrict -Mdiagnostics -cw "$file"
done
# Don't run perlcritic yet.
## Over time, reduce the severity number, eventually to 1.
# perlcritic --severity 5 "$TOPLEVEL"/framework
# Don't run perltidy yet.
# find . \( -name '*.pm' -o -name '*.pl' \) -print0 | xargs -0 perltidy -b

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
