#!/bin/sh

TOPLEVEL="$(git rev-parse --show-toplevel)"

cd "$TOPLEVEL" || (echo "Cannot cd to $TOPLEVEL" && exit 1)

find . \( -name '*.pm' -o -name '*.pl' \) -print0 | xargs -0 -n1 perl -Mstrict -Mdiagnostics -cw

perlcritic "$TOPLEVEL"/framework

# Don't run perltidy yet.
# find . \( -name '*.pm' -o -name '*.pl' \) -print0 | xargs -0 perltidy -b
