Test and analysis scripts
----------------

* `test.include`: Constants and helper functions for test scripts.

* `test_evosuite.sh`: Generates tests with Evosuite and checks whether the
   generated test suites are compatible with the coverage, mutation, and bug
   detection analyses.

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

### Getting started
1. Follow the instructions for setting up Defects4J in the top-level
[README](https://github.com/rjust/defects4j/blob/master/README.md#setting-up-defects4j)

2. Verify you have the perl package for DBI access to CSV files installed:
    - `perldoc DBD/CSV.pm`
    
    If this produces the man page for DBM::CSV you are ok, if not
    you must install the package, e.g., using cpan:
    - `cpan DBD::CSV`

### Running the coverage analysis
3. Please note you must use Java 7; Java 8 will cause failures.

4. Tell the tools which version of Randoop you wish to test:
    By default, the system runs version 3.1.5 of Randoop.
    (Located at "path2defects4j"/framework/lib/test_generation/generation/randooop-current.jar)
    The randoop.jar you wish to test must be named randoop-current.jar.
    - `export TESTGEN_LIB_DIR="path2directory-containing-randoop-current.jar"`

5. Run the test generation and coverage analysis:
    - `./randoop_coverage.sh`

    Currently, this does not generate tests for all the defects, just five in
    each projects for a total of 30 tests. It takes about 90 minutes to run.
    If you wish to override these defaults for `randoop_coverage.sh` you may
    supply an optional project list argument followed by an optional bid list
    argument.
    The test scripts set `TMP_DIR` to */tmp/test_d4j*. If you wish to change
    this, you will need to modify `./test.include`.

6. Display the coverage data:
    The raw coverage data will be found at *$TMP_DIR/test_d4j/coverage*.
    You may display the coverage results by running the perl script:
    - `../util/show_coverage.pl`

    This script will accept an optional argument of an alternative file location.
    Invoke the script with -help for a full list of options.
