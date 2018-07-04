# Buggy lines

Each script in this directory builds upon or extends Defects4J. This means that
the environment variable D4J_HOME needs to be exported; it must point to the
root directory of the Defects4J installation.

# High-level summary

This summary indicates the purpose of each script. Each script provides a
header with more detailed usage information and requirements.

* `get_buggy_lines.sh`: Determine all buggy source code lines in a buggy
Defects4J project version (i.e., all *modified* or *removed* source code lines
in the buggy project version).

* `ask_for_candidates.py`: Asks a human developer to provide a list of
candidate locations for each buggy source code line that has been identified as
*fault of omission*.

* `note_unrankable_lines.py`: Given a list of all buggy source code lines and
correspondent candidates, this script generates a list of all buggy lines that
cannot be mapped to source code line, i.e., that have been considered as
*fault of omission* and there is not any candidate line that can be used to
explain each buggy line.

Note: `ask_for_candidates.py` and `note_unrankable_lines.py` are just
auxiliary scripts of the main script (`get_buggy_lines.sh`). Therefore, it is
recommended that only the main script is executed by the user.

## Determine set of buggy source code lines

Although the set of buggy source code lines is automatically identified by the
`get_buggy_lines.sh` script, for some bugs, a human developer would have to be
consulted.

To "identify a set of faulty lines", the `get_buggy_lines.sh` script goes
through all Defects4J's bugfix patches, and from that patch, generates all of
the `.buggy.lines` files in the `buggy_lines` directory of each project.

There are two kinds of fault: changes (including deletions) and omissions.
Omissions are different in that there may have been many places the developer
*could* have added code to fix the bug, e.g., perhaps the bugfix involved
adding a counter that's incremented every iteration of a loop; but it could be
incremented anywhere in the loop, not *only* at the point where the developer
actually added the code.

For such cases, a human developer must manually examine every fault of omission
identified in the `.buggy.lines` files, and determined which set of lines the
omission could have been inserted at. This information is then inserted into a
corresponding `.candidates` file (also in the `buggy_lines` directory of each
project). This is done by the `ask_for_candidates.py` script (which is
automatically called by the `get_buggy_lines.sh` script when necessary).

### How to identify candidates (i.e., candidate locations) for a deleted statement

Generally, the candidates for a deleted statement are the previous executable
statement and the next executable statement, however, there are some other
cases to which the candidate location(s) is more difficult to identify. The
following sections describe a simple methodology to identify candidate
locations for deleted statements.

#### Methodology

We only consider the lexical structure of a program and the control flow graph
(no slicing, no following of def-use chains). We require the next executable
statement to be the closest executable statement that appears lexically after
the deleted statement. We require the previous executable statement to be the
closest executable statement that appears lexically before the deleted
statement. The rationale is that a programmer is looking at the source code:
a tool should report lines that are as close as possible, in the source code,
to the deleted statement.

Considering the control flow graph or the lexical structure of a program gives
the same result for all non-conditional statements. We generally consider the
control flow graph to determine the previous and next executable statements
with the exception of loops. Within loops, we look only forward when
determining the next executable statement: If the last statement in a loop
body is missing, the next executable statement appears after the loop body
(i.e., we ignore the edge back to the condition of the loop). For consistency,
the set of previous executable statements of a deleted statement that appears
immediately after a for loop includes the last statement in the for loop body
(see example in section 'Deletion after a loop').

For a deleted statement that could be inserted in multiple locations, the set
of candidate locations is the union of the next executable and previous
executable statement(s) for each of those insertion locations.

##### Including non-executable statements

When looking for the previous or next executable statement, we include all of
the following but continue:

* Declarations (including synchronized)
* Labels
* Curly braces

We stop at an executable statement.

##### Additional rules

* The beginning of a declaration of a method, constructor, or static
initializer is the **first** possible executable **statement** in that method,
constructor, or initializer.
* The closing curly brace of a method, constructor, or static initializer is
the **last** possible executable **statement** in that method, constructor, or
initializer.
* We do **not** include empty lines and comments.

##### Multi-statement lines and multi-line statements

* Line breaks are irrelevant. We apply the same methodology for a
single-statement line, a multi-statement line, or a multi-line statement.
* Example: `case x: foo(); break;`
  * If `foo()` is deleted:
    * To determine the previous executable statement, consider `case x:`,
    include it as a candidate because it is non-executable, and continue
    looking on the previous line. This would be the same if `case x:`,
    appeared on its own line above `foo()`. `break` is the next executable
    statement.
  * If `break` is deleted:
    * `foo()` is the previous executable statement look for the next
    executable statement on the next line(s).

#### Examples

Example of three different Control Flow Graphs (CFG). Nodes are represented by
`()`, directed edges are represented by `\` or `/`, and loops with two nodes
are represented by `//`. For example, `\` connects nodes `(1)` and `(3)` but
not `(3)` and `(1)`, and `//` represents a loop with nodes `(1)` and `(2)`.

```
      (1)             (1)             (1)
      / \             / \            // \
    (2) (3)         (2) (3)         (2) (3)
     \   /
      (4)

      (a)             (b)             (c)
```

In each of the following examples, the marker (`<--`) points to the previous
and next executable statements.

##### Deletion after If-else statement

Include both branches when the previous statement is a conditional statement -
see nodes `(2)`, `(3)`, and `(4)` in CFG a), e.g.,:

```java
1 if(x) {
2   foo();              <-- previous statement
3 } else {
4   bar();              <-- previous statement
5 }
6 // deleted statement
7 nextStmt;             <-- next statement
```

Candidates: `(2)`, `(3)`, `(4)`, `(5)`, `(7)`

##### Deletion after If statement

Include both branches, one of which is missing so the CFG connects directly to
the condition - see nodes `(1)`, `(2)`, and `(3)` in CFG b):

```java
1 if(x) {               <-- previous statement
2   foo();              <-- previous statement
3 }
4 // deleted statement
5 nextStmt;             <-- next statement
```

Candidates: `(1)`, `(2)`, `(3)`, `(5)`

##### Deletion after a loop

Include both previous executable statements, lexically and according to the
CFG - see nodes `(1)`, `(2)`, and `(3)` in CFG c):

```java
1 for(x) {              <-- previous statement
2   foo();              <-- previous statement
3 }
4 // deleted statement
5 nextStmt;             <-- next statement
```

Candidates: `(1)`, `(2)`, `(3)`, `(5)`

##### Deletion at the end of a loop body

Include the lexically next executable statement - that is, skip node `(1)` in
CFG c):

```java
1 for(x) {
2   foo();              <-- previous statement
3 // deleted statement
4 }
5 nextStmt;             <-- next statement
```

Candidates: `(2)`, `(4)`, `(5)`

##### Deletion at the end of a try block (within a try-catch-finally block)

Exclude the catch block:

```java
1  try {
2    ...
3    if (x) {           <-- previous statement
4      // deleted statement   
5    }
6  } catch (y) {
7    ...
8  } finally {
9    nextStmt;          <-- next statement
10 }
```

Candidates: `(3)`, `(5)`, `(6)`, `(8)`, `(9)`

##### Deletion at the end of a try block (within a try-catch block)

Exclude the catch block:

```java
1  try {
2    ...
3    if (x) {           <-- previous statement
4      // deleted statement   
5    }
6  } catch (y) {
7    ...
8  }
9  nextStmt;            <-- next statement
```

Candidates: `(3)`, `(5)`, `(6)`, `(9)`

##### Deletion at the beginning of a method body

Include the declaration as the previous executable statement:

```java
1  public void foo () { <-- previous statement
2    // deleted statement   
3    nextStmt;          <-- next statement
4  }
```

Candidates: `(1)`, `(3)`

##### Multiple candidate locations (e.g., deletion in an initializer block)

Include the previous and next executable statement(s) for each candidate
locations:

```java
1 map = new HashMap();  <-- first possible previous statement
2 map.put(k1, v1);
3 // deleted statement   
4 map.put(k3, v3);
5 map.put(k4, v4);
6 return map;           <-- last possible next statement
```

Candidates: `(1)`, `(2)`, `(4)`, `(5)`, `(6)`
