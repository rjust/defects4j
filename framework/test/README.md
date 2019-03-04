Test and analysis scripts
----------------

* `test.include`: Constants and helper functions for test scripts.

* `test_evosuite.sh`: Generates tests with Evosuite and checks whether the
   generated test suites are compatible with the coverage, mutation, and bug
   detection analyses.

* `test_export_command.sh`: Tests the
  [export](https://github.com/rjust/defects4j/blob/master/framework/bin/d4j/d4j-export) command.

* `test_fix_test_suite.sh`: Tests the
  [fix_test_suite.pl](https://github.com/rjust/defects4j/blob/master/framework/util/fix_test_suite.pl) script.

* `test_mutation_analysis.sh`: Tests various options for the mutation analysis.

* `test_randoop.sh`: Generates tests with Randoop and checks whether the
   generated test suites are compatible with the coverage, mutation, and bug
   detection analyses.

* `test_sanity_check.sh`: Checks out each buggy and fixed project version and
   makes sure that it compiles.

* `test_tutorial.sh`: Runs the tutorial described in the top-level
   [README](https://github.com/rjust/defects4j#using-defects4j).

* `test_verify_bugs.sh`: Reproduces each defect and verifies the triggering
   tests.

Randoop coverage on the Defects4J defects
----------------
This section describes how to calculate Randoop code coverage over the Defects4J
defects (see the top-level
[README](https://github.com/rjust/defects4j/blob/master/README.md) for
more details about the defects and requirements).

1. Optionally, indicate where to find the version of Randoop you wish to test.
    - `export TESTGEN_LIB_DIR="path2directory-containing-randoop-current.jar"`

    The randoop.jar you wish to test must be named randoop-current.jar.
    By default, the system runs version 4.0.4 of Randoop,
    located at "path2defects4j"/framework/lib/test_generation/generation/randooop-current.jar.
    If you change the default version of randoop-current.jar you must also copy the
    matching version of replacecall.jar to replacecall-current.jar in the same location as
    randoop-current.jar.

2. Run the test generation and coverage analysis:
    - `./randoop_coverage.sh`

    Currently, this does not generate tests for all the defects, just five in
    each project for a total of 30 tests. It takes about 90 minutes to run.
    If you wish to override these defaults for `randoop_coverage.sh` you may
    supply an optional project list argument followed by an optional bid
    (bug id) list argument.
    The test scripts set `TMP_DIR` to */tmp/test_d4j*. If you wish to change
    this, you will need to modify `./test.include`.

3. Display the coverage data:
    - `../util/show_coverage.pl`

    The raw coverage data is found at *$TMP_DIR/test_d4j/coverage*.
    This script will accept an optional argument of an alternative file location.
    Invoke the script with `-help` for a full list of options.
