#!/usr/bin/env python
#
# --------------------------------------------------------------------
# This script analyses two files: 1) a file that contains all buggy
# lines of a specific Defects4J project version, and 2) a file with
# a list of candidates for each FAULT_OF_OMISSION defined in the first
# file; and generates a list of all buggy lines that cannot be ranked,
# i.e., that have been considered as a FAULT_OF_OMISSION and there is
# not any candidate line that can be used to explain the buggy one.
#
# Each row of the buggy lines file is composed by two columns: first
# row is composed by the path to the java file followed by a # and a
# number. The second column can represent a Java line of code or
# FAULT_OF_OMISSION. For example,
#   org/apache/commons/lang3/math/NumberUtils.java#468#            if (hexDigits > 16) { // too many for Long
#   org/apache/commons/lang3/math/NumberUtils.java#471#            if (hexDigits > 8) { // too many for an int
#   org/apache/commons/lang3/math/NumberUtils.java#467#FAULT_OF_OMISSION
#
# In here, line 468 of the .../NumberUtils.java file is composed by
# Java source code, whereas line 467 has been considered as a
# FAULT_OF_OMISSION.
#
# Each row of the candidates file is also composed by two columns. The
# first column is structured the same way as in the buggy lines file,
# and second column represents the source code line that can be a
# candidate to explain the buggy line described in the first column.
# For example,
#   org/apache/commons/lang3/math/NumberUtils.java#467,org/apache/commons/lang3/math/NumberUtils.java#466
#   org/apache/commons/lang3/math/NumberUtils.java#467,org/apache/commons/lang3/math/NumberUtils.java#467
#
# The output file (unrankable lines file) includes all buggy lines
# that have been identified as FAULT_OF_OMISSION in the buggy lines
# file and that there are not any candidate line in the candidates
# file that can used to explain the buggy one.
#
# Usage:
# note_unrankable_lines.py <buggy-lines-file> <candidates-file> <unrankable-lines-file> 
#
# Parameters:
#  - --buggy-lines-file a list of all buggy lines of a specific
#    Defects4J project version.
#  - --candidates-file a list of source code lines that can explain
#    the buggy lines annotated with FAULT_OF_OMISSION.
#  - --unrankable-lines-file a list of all buggy lines that can be
#    ranked, i.e., there are not any candidate that can be used to
#    explain each buggy line.
#
# Requirements:
#  - Python >= 2.7
# --------------------------------------------------------------------

import sys
import argparse

def parse_buggy_line(buggy_line_info):
  """ Parse a buggy line.

  Args:
    buggy_line_info: A buggy line can represent one of two types:
       1) a Java line of code, e.g., org/apache/commons/lang/time/DurationFormatUtils.java#306#            days += 31;
    or 2) a FAULT_OF_OMISSION, e.g., org/apache/commons/lang/time/DurationFormatUtils.java#313#FAULT_OF_OMISSION

  Returns:
    A string split by '#'.
  """

  path, lno, source = buggy_line_info.split(b'#', 2)
  return (path+b'#'+lno, source)

parser = argparse.ArgumentParser()
parser.add_argument('--buggy-lines-file', required=True) # input
parser.add_argument('--candidates-file', required=True) # input
parser.add_argument('--unrankable-lines-file', required=True) # output

args = parser.parse_args()

with open(args.buggy_lines_file, 'rb') as f:
  buggy_lines_needing_candidates = dict(parse_buggy_line(l.strip()) for l in f if b'FAULT_OF_OMISSION' in l)
try:
  with open(args.candidates_file, 'rb') as f:
    buggy_lines_with_candidates = set(l.strip().split(b',')[0] for l in f)
except IOError:
  buggy_lines_with_candidates = set()

buggy_lines_needing_but_lacking_candidates = set(buggy_lines_needing_candidates.keys()) - buggy_lines_with_candidates

if buggy_lines_needing_but_lacking_candidates:
  with open(args.unrankable_lines_file, 'wb') as f:
    f.write(b''.join(line+b'#'+buggy_lines_needing_candidates[line]+b'\n' for line in buggy_lines_needing_but_lacking_candidates))

sys.exit(0)
