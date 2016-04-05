Defects4J -- version 1.0.1
----------------
Defects4J is a collection of reproducible bugs collected with the goal of
advancing software testing research.

The projects
---------------
Defects4J contains bugs from the following open-source projects:

| Identifier | Project name         | Number of bugs |
|------------|----------------------|----------------|
| Chart      | JFreechart           |  26            |
| Closure    | Closure compiler     | 133            |
| Lang       | Apache commons-lang  |  65            |
| Math       | Apache commons-math  | 106            |
| Time       | Joda-Time            |  27            |

The bugs
---------------
Each bug has the following properties:

- Issue filed in the corresponding issue tracker, and issue tracker identifier
  mentioned in the fixing commit message.
- Fixed in a single commit -- manually verified to not include irrelevant
  changes (e.g., refactorings or feature additions).
- Fixed by modifying the source code (as opposed to configuration files,
  documentation, or test files).
- A triggering test exists that failed before the fix and passes after the fix
  -- the test failure is not random or dependent on test execution order.

(B)uggy and (f)ixed program revisions are labelled with `<id>b` and `<id>f`,
respectively (`<id>` is an integer).

Requirements
----------------
 - Java 1.7
 - Perl >= 5.0.10
 - Git >= 1.9
 - SVN >= 1.8

All bugs have been reproduced and triggering tests verified, using the latest
version of Java 1.7.
Note that using Java 1.8+ might result in unexpected failing tests on a fixed
program version.

Getting started
----------------
#### Setting up Defects4J
1. Clone Defects4J:
    - `git clone https://github.com/rjust/defects4j`

2. Initialize Defects4J (download the project repositories and external libraries, which are not included in the git repository for size purposes and to avoid redundancies):
    - `cd defects4j`
    - `./init.sh`

3. Add Defects4J's executables to your PATH:
    - `export PATH=$PATH:"path2defects4j"/framework/bin`

#### Using Defects4J
4. Check installation and get information for a specific project (commons lang):
    - `defects4j info -p Lang`

5. Get information for a specific bug (commons lang, bug 1):
    - `defects4j info -p Lang -b 1`

6. Checkout a buggy source code version (commons lang, bug 1, buggy version):
    - `defects4j checkout -p Lang -v 1b -w /tmp/lang_1_buggy`

7. Change to the working directory, compile sources and tests, and run tests:
    - `cd /tmp/lang_1_buggy`
    - `defects4j compile`
    - `defects4j test`

8. More examples of how to use the framework are available in `framework/test`

Publications
------------------
* "Defects4J: A Database of Existing Faults to Enable Controlled Testing Studies for Java Programs"
    René Just, Darioush Jalali, and Michael D. Ernst,
    ISSTA 2014 [[download]][issta14].

* "Are Mutants a Valid Substitute for Real Faults in Software Testing?"
    René Just, Darioush Jalali, Laura Inozemtseva, Michael D. Ernst, Reid Holmes, and Gordon Fraser,
    FSE 2014 [[download]][fse14].

[issta14]: http://homes.cs.washington.edu/~rjust/publ/defects4j_issta_2014.pdf
[fse14]: http://homes.cs.washington.edu/~rjust/publ/mutants_real_faults_fse_2014.pdf

Documentation
--------------------
A detailed documentation for any script or module is available as
[html documentation][htmldocs].

[htmldocs]: http://people.cs.umass.edu/~rjust/defects4j/html_doc/index.html

Command-line interface
-----------------------
Use `framework/bin/defects4j` to execute any of the following commands:

| Command        | Description                                                                                       |
|----------------|---------------------------------------------------------------------------------------------------|
| info           | View configuration of a specific project or summary of a specific bug                             |
| checkout       | Checkout a buggy or a fixed project version                                                       |
| compile        | Compile sources and developer-written tests of a buggy or a fixed project version                 |
| test           | Run a single test or a test suite on a buggy or a fixed project version                           |
| mutation       | Run mutation analysis on a buggy or a fixed project version                                       |
| coverage       | Run code coverage analysis on a buggy or a fixed project version                                  |
| monitor.test   | Monitor the class loader during the execution of a single test or a test suite                    |
| export         | Export version-specific properties such as classpaths, directories, or lists of tests             |


Export version-specific properties
----------------------------------
Use `defects4j export -p <property_name> [-o output_file]` in the working
directory to export a version-specific property:

| Property         | Description                                                                         |
|------------------|-------------------------------------------------------------------------------------|
| classes.modified | Classes (source files) modified by the bug fix                                      |
| cp.compile       | Classpath to compile and run the project                                            |
| cp.test          | Classpath to compile and run the developer-written tests                            |
| dir.src.classes  | Source directory of classes (relative to working directory)                         |
| dir.bin.classes  | Target directory of classes (relative to working directory)                         |
| dir.src.tests    | Source directory of tests (relative to working directory)                           |
| tests.all        | List of all developer-written tests                                                 |
| tests.relevant   | List of relevant tests (i.e., tests that touch at least one of the modified classes |
| tests.trigger    | List of tests that trigger (expose) the bug                                         |

Test execution framework
--------------------------
The test execution framework for generated test suites (`framework/bin`)
provides the following scripts:

| Script            | Description                                                     |
|-------------------|-----------------------------------------------------------------|
| run_bug_detection | ^Determine the real fault detection rate                        |
| run_mutation      | ^Determine the mutation score                                   |
| run_coverage      | ^Determine code coverage ratios (statement and branch coverage) |
| run_evosuite      | Generate test suites using EvoSuite                             |
| run_randoop       | Generate test suites using Randoop                              |
^Note that this script requires Perl DBI.

Directory structure
----------------------
This is the top-level directory of Defects4J.
The directory structure is as follows:

    defects4j
       |
       |--- project_repos:     The version control repositories of the provided projects.
       |
       |--- major:             The Major mutation framework.
       |
       |--- framework:         Libraries and executables of the database abstraction and
           |                   test execution framework.
           |
           |--- bin:           Command line interface to Defects4J.
           |
           |--- core:          The modules of the core framework.
           |
           |--- lib:           Libraries used in the core framework.
           |
           |--- util:          Util scripts used by Defects4J.
           |
           |--- projects:      Project-specific resource files.
           |
           |--- test:          Scripts to test the framework.

License
---------
MIT License, see `license.txt` for more information.

