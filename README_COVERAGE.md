Randoop coverage using the Defects4J test suites
----------------
Defects4J is a collection of reproducible bugs collected with the goal of
advancing software testing research.
(See README.md in this directory for more information.)

This README describes some changes to and additional tools added to
Defects4j to calculate Randoop code coverage over the Defects4j test suites.

Defects4J contains 395 bugs from the following open-source projects:

| Identifier | Project name         | Number of bugs |
|------------|----------------------|----------------|
| Chart      | JFreechart           |  26            |
| Closure    | Closure compiler     | 133            |
| Lang       | Apache commons-lang  |  65            |
| Math       | Apache commons-math  | 106            |
| Mockito    | Mockito              |  38            |
| Time       | Joda-Time            |  27            |

Requirements
----------------
 - Java 1.7
 - Perl >= 5.0.10
 - Git >= 1.9
 - SVN >= 1.8

All bugs have been reproduced and triggering tests verified, using the latest
version of Java 1.7. All suites except Mockito seem to work with Java 1.8;
however, the default coverage script runs all suites so you will need to
have Java 1.7 as your default.

Getting started
----------------
1. Clone Defects4J:
    - `git clone https://github.com/rjust/defects4j`

2. Initialize Defects4J (download the project repositories and external libraries,
which are not included in the git repository for size purposes and to avoid redundancies):
    - `cd defects4j`
    - `./init.sh`

3. Add Defects4J's executables to your PATH:
    - `export PATH=$PATH:"path2defects4j"/framework/bin`

4. Set the temp directory environment variable:
    - `export TMP_DIR="path2yourtmpdir"`

5. Verify you have the perl package for DBI access to CSV files:
    - `perldoc DBD/CSV.pm`
    If this produces the man page for DBM::CSV you are ok, if not
    you must install the package:
    - `cpan DBD::CSV`

Running the coverage tests
----------------
6. Tell the tools which version of Randoop you wish to test:
    By default, the system runs an old (3.1.0) version of Randoop.
    The randoop.jar you wish to test must be named randoop-current.jar.
    - `export TESTGEN_LIB_DIR="path2directory-containing-randoop-current.jar"`

7. Run the coverage suite:
    - `cd framework/test`
    - `bash -v ./run-test.sh`
    Currently, this does not run all the tests, just five in each of the suites
    for a total of 30 tests. It takes about 90 minutes to run.

8. Calculate the coverage:
    The raw coverage data will be found at $TMP_DIR/test_d4j/coverage.
    - `./calc-coverage.pl $TMP_DIR/test_d4j/coverage`

