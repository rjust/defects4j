Defects4J
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

Getting started
----------------
1. Download the repositories for the projects by running:
    - `cd project_repos`
    - `./get_repos.sh`
   These are not included in this repository for size purposes and to avoid
   redundancies.

2. Add Defects4J's executables to your PATH:
    - `export PATH=$PATH:"path2defects4j"/framework/bin`

3. Check installation and get information for a specific project (commons lang):
    - `defects4j info -p Lang`

4. Get information for a specific bug (commons lang, bug 1):
    - `defects4j info -p Lang -v 1`

5. Checkout a buggy source code version (commons lang, bug 1, buggy version):
    - `defects4j checkout -p Lang -v 1b -w /tmp/lang_1_buggy`

6. Change to the working directory, compile sources and tests, and run tests:
    - `cd /tmp/lang_1_buggy`
    - `defects4j compile`
    - `defects4j test`

7. More examples of how to use the framework are available in `test.sh`

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
Detailed documentation for any script or module can be viewed with:
`perldoc <file>`

Database abstraction
-----------------------
Use `framework/bin/defects4j` to:

  - view configuration of a specific project
  - view summary of a specific bug
  - checkout and compile faulty or fixed project versions
  - run test suite on faulty or fixed project versions
  - perform mutation analysis on fixed project versions

Test execution framework
--------------------------
The test execution framework provides the following scripts:
  - framework/bin/run_bug_detection.pl:         
    Determines real fault detection rates of generated test suites and stores
    the results in a csv-based database. Note that this script requires Perl DBI.    
                                                                                 
  - framework/bin/run_mutation.pl:                                               
    Determines mutation scores of generated test suites and stores the results   
    in a csv-based database. Note that this script requires Perl DBI.                
                                                                                 
  - framework/bin/run_coverage.pl:                                               
    Determines code coverage ratios of generated test suites and stores the      
    results in a csv-based database. Note that this script requires Perl DBI.        
                                                                                 
  - framework/bin/run_evosuite.pl: 
    Generates test suites using EvoSuite.         
                                                                                 
  - framework/bin/run_randoop.pl: 
    Generates test suites using Randoop.

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
           |--- projects:      Project-specific resource files

License
---------
MIT License, see `license.txt` for more information.

