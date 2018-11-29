#!/usr/bin/env bash
# small utility script that verifies that an issue ID occurs as a bug on a sourceforge tracker.

wget -q -O /dev/null "http://sourceforge.net/p/$1/bugs/$2/"
exit $?
