#!/usr/bin/env python
#
# --------------------------------------------------------------------
# This script creates a list of Java lines of code (each with a
# suspiciousness value) from a list of Java statements (each with a
# suspiciousness value). The suspiciousness value of each line of code
# is extracted from its statement.
#
# Usage:
# statement-suspiciousness-to-source_code_line-suspiciousness.py
#             <STATEMENTS FILE> <SOURCE CODE LINES FILE> <OUTPUT FILE>
#
# Parameters:
#  - <STATEMENTS FILE> A file that lists all statements reported by a
#    fault localization technique/tool. The file should contains a
#    header with two columns: 'name' and 'suspiciousness_value'
#    (separated by ';'). Each row of the file represents a statement
#    and it should be composed by a statement name and a
#    suspiciousness value (both separated by ';'). E.g.,
#    name;suspiciousness_value
#    org.jfree.chart.renderer.category$AbstractCategoryItemRenderer#getLegendItems():1793;1.0
#    org.jfree.chart.plot$CategoryPlot#setRenderer(org.jfree.chart.renderer.category.CategoryItemRenderer):1613;0.4472135954999579
#    org.jfree.chart.plot$CategoryPlot#setRenderer(org.jfree.chart.renderer.category.CategoryItemRenderer):1614;0.4472135954999579
#    ...
#
#  - <SOURCE CODE LINES FILE> A file that lists all source code lines
#    of a specific project/bug. Each row of the file follows the
#    following format, e.g.:
#    org/jfree/chart/util/StrokeList.java#161:org/jfree/chart/util/StrokeList.java#162
#    org/jfree/chart/plot/Plot.java#195:org/jfree/chart/plot/Plot.java#196
#    org/jfree/chart/plot/Plot.java#195:org/jfree/chart/plot/Plot.java#197
#
#  - <OUTPUT FILE> A file to which the conversion from statements to
#    lines of code should be written. The output file contains a
#    header with two columns: 'Line', 'Suspiciousness' (separated by
#    ','). Each row of the file represents a line of code (rather than
#    a statement) (both separated ','). E.g.,
#    Line,Suspiciousness
#    org/jfree/chart/renderer/category/AbstractCategoryItemRenderer.java#1793,1.0
#    org/jfree/chart/plot/CategoryPlot.java#1613,0.4472135954999579
#    org/jfree/chart/plot/CategoryPlot.java#1614,0.4472135954999579
#
# Requirements:
#  - Python >= 2.7
# --------------------------------------------------------------------

import sys
import argparse
import csv

def classname_to_filename(classname):
  """ Coverts a Java class name to a file name.

  Replaces the character '.' within a Java class name with '/' and
  appends the string '.java'.

  Args:
    classname: A string representing the name of a Java class.

  Returns:
    A file name of a Java class name.
  """

  packagename = classname[:classname.find('$')].replace('.', '/')
  if len(packagename) > 0:
    packagename += "/"

  singleclassname = classname[classname.find('$')+1:classname.find('#')]
  if '$' in singleclassname:
    # get rid of inner/anonymous classes
    singleclassname = singleclassname[:singleclassname.find('$')]

  return packagename + singleclassname + ".java"

assert classname_to_filename('org.foo$Bar#methodX(int)')    == 'org/foo/Bar.java'
assert classname_to_filename('org.foo$Bar$Inner#methodY()') == 'org/foo/Bar.java'
assert classname_to_filename('$Bar#methodX(int)')           == 'Bar.java'
assert classname_to_filename('$Bar$Inner#methodY()')        == 'Bar.java'

def stmtclassname_to_stmtfilename(stmt):
  """ Converts the Java class name within a code statement into a file
  name.

  Replaces the character '.' within a code statement with '/', and
  appends the string '.java'.

  Args:
    stmt: A string representing a statement name (i.e., a Java class
    name followed by a statement number).

  Returns:
    A code statement formed by a file name and a statement number.
  """

  classname, lineno = stmt.rsplit(':', 1)
  return '{}#{}'.format(classname_to_filename(classname), lineno)

assert stmtclassname_to_stmtfilename('org.foo$Bar#methodX(int):123')    == 'org/foo/Bar.java#123'
assert stmtclassname_to_stmtfilename('org.foo$Bar$Inner#methodY():123') == 'org/foo/Bar.java#123'
assert stmtclassname_to_stmtfilename('$Bar#methodX(int):123')           == 'Bar.java#123'
assert stmtclassname_to_stmtfilename('$Bar$Inner#methodY():123')        == 'Bar.java#123'

parser = argparse.ArgumentParser()
parser.add_argument('--stmt-susps-file', required=True)
parser.add_argument('--source-code-lines-file', required=True)
parser.add_argument('--output-file', required=True)

args = parser.parse_args()

source_code = dict()
with open(args.source_code_lines_file) as f:
  for line in f:
    line = line.strip()
    entry = line.split(':')
    key = entry[0]
    if key in source_code:
      source_code[key].append(entry[1])
    else:
      source_code[key] = []
      source_code[key].append(entry[1])

source_code_lines_and_suspiciousness_values = dict()
with open(args.stmt_susps_file) as fin:
  reader = csv.DictReader(fin, delimiter=';')
  with open(args.output_file, 'w') as f:
    writer = csv.DictWriter(f, ['Line','Suspiciousness'])
    writer.writeheader()
    for row in reader:
      line = stmtclassname_to_stmtfilename(row['name'])
      susps = row['suspiciousness_value']

      if line in source_code_lines_and_suspiciousness_values:
        # For a bytecode statement there could exist more than one bytecode
        # description, for instance, the first bytecode statement of an anonymous
        # class also exists in the super class (however with another bytecode
        # description). To avoid reporting duplicate lines, a dictionary of
        # lines is used. Note: those duplicate lines have exactly the same
        # suspiciousness value.
        continue
      else:
        source_code_lines_and_suspiciousness_values[line] = susps

      writer.writerow({'Line': line, 'Suspiciousness': susps})

      # check whether there are any sub-lines
      if line in source_code:
        for additional_line in source_code[line]:
          writer.writerow({'Line': additional_line, 'Suspiciousness': susps})
  f.close()
fin.close()

sys.exit(0)
