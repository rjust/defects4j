#!/usr/bin/env python
#
# --------------------------------------------------------------------
# This script ask a human developer for a list of lines that could be
# candidate lines of buggy lines that have been considered as
# FAULT_OF_OMISSION. In order to do it, this scripts shows the user
# the patch and asks which lines are candidates for which faults of
# omission.
#
# Usage:
#   python ask_for_candidates.py \
#       --buggy-directory <dir> \
#       --fixed-directory <dir> \
#       --buggy-lines-file <file> \
#       --candidates-file <file> \
#       [--diff-viewer <diff program, default is meld>]
#
# Parameters:
#  - --buggy-directory path to a directory with the buggy version of a
#    Defects4J project version.
#  - --fixed-directory path to a directory with the fixed version of a
#    Defects4J project version.
#  - --buggy-lines-file a list of all buggy lines of a specific
#    Defects4J project version.
#  - --candidates-file a list of source code lines that can explain
#    the buggy lines annotated with FAULT_OF_OMISSION.
#
# Requirements:
#  - Python >= 2.7
#  - The default diff viewer is meld -- you can change the diff viewer
#    by setting optional the --diff-viewer option.
# --------------------------------------------------------------------

import sys
import subprocess
import collections
import argparse

def compare_dirs(buggy_dir, fixed_dir, src_dir):
  subprocess.call(
    '{view} {buggy}/{source} {fixed}/{source} 2> /dev/null &'.format(
      view=args.diff_viewer,
      buggy=buggy_dir,
      fixed=fixed_dir,
      source=src_dir),
    shell=True)

def replace_line_number(line, new_number):
  return '{path}#{number}'.format(path=line[:line.index('#')], number=new_number)

parser = argparse.ArgumentParser()
parser.add_argument('--buggy-directory', required=True) # input
parser.add_argument('--fixed-directory', required=True) # input
parser.add_argument('--src-dir', required=True) # input
parser.add_argument('--buggy-lines-file', required=True) # input
parser.add_argument('--candidates-file', required=True) # output
parser.add_argument('--diff-viewer', default='meld', required=False)

args = parser.parse_args()

omission_lines = [line.strip().replace('#FAULT_OF_OMISSION', '')
                  for line in open(args.buggy_lines_file, 'rb')
                  if 'FAULT_OF_OMISSION' in line]
if not omission_lines:
  sys.exit(0)

compare_dirs(args.buggy_directory, args.fixed_directory, args.src_dir)

candidates_by_line = collections.defaultdict(set)
for omission_line in omission_lines:
  line_ranges_string = raw_input('Candidates for {}: '.format(omission_line)).strip()
  if (len(line_ranges_string) == 0):
    continue
  line_ranges = [w.strip() for w in line_ranges_string.split(',')]

  for line_range in line_ranges:
    if (len(line_range) == 0):
      continue
    if '-' in line_range:
      first, last = line_range.split('-')
      first, last = int(first), int(last)
      candidates_by_line[omission_line].update(
        replace_line_number(omission_line, n)
        for n in range(first, last+1))
    else:
      candidates_by_line[omission_line].add(replace_line_number(omission_line, line_range))

summary = ''.join('{},{}\n'.format(omission_line, candidate)
  for omission_line, candidates in candidates_by_line.items()
  for candidate in sorted(candidates))

with open(args.candidates_file, 'w') as f:
  f.write(summary)

sys.exit(0)
