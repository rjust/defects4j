Test and analysis scripts
----------------

* `test.include`: Constants and helper functions for test scripts.

* `test_bug_mining.sh`: Tests the
  [bug-mining](https://github.com/rjust/defects4j/blob/master/framework/bug-mining) infrastructure.

* `test_export_command.sh`: Tests the
  [export](https://github.com/rjust/defects4j/blob/master/framework/bin/d4j/d4j-export) command.

* `test_fix_test_suite.sh`: Tests the
  [fix_test_suite.pl](https://github.com/rjust/defects4j/blob/master/framework/util/fix_test_suite.pl) script.

* `test_gen_tests.sh`: Tests the
  [gen_tests.pl](https://github.com/rjust/defects4j/blob/master/framework/bin/gen_tests.pl) script.
  Specifically, this script tests the integration of all supported test
  generators and the compatibility of the generated test suites with the
  coverage, mutation, and bug detection analyses.

* `test_mutation_analysis.sh`: Tests various options for the mutation analysis.

* `test_sanity_check.sh`: Checks out each buggy and fixed project version and
  checks for compilation and required properties.

* `test_tutorial.sh`: Runs the tutorial described in the top-level
   [README](https://github.com/rjust/defects4j#using-defects4j).

* `test_verify_bugs.sh`: Reproduces a bug, or a set of bugs, and verifies that
   the observed set of triggering tests matches the expected set of triggering
   tests.

Randoop coverage on the Defects4J defects
----------------
This section describes how to calculate Randoop code coverage over the Defects4J
defects (see the top-level
[README](https://github.com/rjust/defects4j/blob/master/README.md) for
more details about the defects and requirements).

1. Follow steps 1-4 under
   [Steps to set up
   Defects4J](https://github.com/rjust/defects4j/blob/master/README.md#steps-to-set-up-defects4j)
   in the top-level README.

2. Optionally, use a different version of Randoop.

   By default, the system uses the version of Randoop at
   "path2defects4j"/framework/lib/test_generation/generation/randooop-current.jar.

    * You can indicate a different directory that contains Randoop (note that the `.jar` files must be suffixed `-current.jar`):
      ```export TESTGEN_LIB_DIR="path-to-directory-containing-randoop-current.jar"```
    * You can copy and rename `.jar` files from a local version of Randoop:
      ```
      (cd MY_RANDOOP && ./gradlew assemble) && (cd $D4J_HOME/framework/lib/test_generation/generation && MY_RANDOOP/scripts/replace-randoop-jars.sh "-current")
      ```

3. Run the test generation and coverage analysis:
    - `./randoop_coverage.sh`

    Currently, this does not generate tests for all the defects, just five in
    each project for a total of 30 tests. It takes about 90 minutes to run.
    If you wish to override these defaults for `randoop_coverage.sh` you may
    supply an optional project list argument followed by an optional bid
    (bug id) list argument.
    The test scripts set `TMP_DIR` to */tmp/test_d4j*. If you wish to change
    this, you will need to modify `./test.include`.

4. Display the coverage data:
    - `../util/show_coverage.pl`

    The raw coverage data is found at *$TMP_DIR/test_d4j/coverage*.
    This script will accept an optional argument of an alternative file location.
    Invoke the script with `-help` for a full list of options.
