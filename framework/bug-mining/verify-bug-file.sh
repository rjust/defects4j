#!/usr/bin/env bash
# small utility script that verifies that an issue ID occurs in a specified file.

grep -qi "^$2," "$1"
exit $?
