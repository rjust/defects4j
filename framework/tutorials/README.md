How to use Defects4J
================
This document provides tutorials for how to use Defects4J and how to extend it.
The primary audience of these tutorials are researchers who wish to experiment
with Defects4J.

Test generation
===============

Generating tests
----------------

Evaluating test generators
--------------------------

Adding new test generators
--------------------------


Fault localization
==================


Program repair
==============


FAQ
==============
How can I obtain the set of all executed test cases (JUnit test methods)?

The `defects4j test` and `defects4j` coverage commands output the following two
files in the working directory:
1. `all_tests`: All executed tests (one per line).
2. `failng_tests`: Tests that failed during execution, together with the
   corresponding stack trace.
