Overview of the bug-mining process
----------------------------
1. Initialize a bug-mining working directory and configuring a project for bug mining.

2. Identify candidate bugs by cross-referencing the project's version control
   history with the project's bug tracker.

3. Analyze the pre-fix and post-fix revisions of the candidate bugs:
   Identify all bugs whose pre-fix and post-fix revisions are compilable and
   testable.

4. Reproduce bugs: Run the project's tests to verify that each bug can be reliably
   reproduced with at least one bug-triggering test that fails on the pre-fix
   and passes on the post-fix revision.

5. Review and isolate bugs: Manually minimize the bug if necessary (i.e.,
   eliminate features or refactorings).

6. Promote all reproducible minimized bugs to the main `Defects4J` database!

Initializing the bug-mining working directory and configuring the project
-------------------------
A Perl module, a wrapper build file, and a cloned repository are necessary to
mine defects for a (new) project in `Defects4J` -- templates and a wrapper
script exist that ease the configuration process.

1. Suppose the project's name is `my-awesome-project`, the project's repository
   URL is `https://github.com/my-awesome-project`, and the short, descriptive
   *project id* is `MyProject`, then configure the project for bug mining with:
```
./create-project.pl -p MyProject -n my-awesome-project -w bug-mining -r https://github.com/my-awesome-project
```

This command initializes the *bug-mining* working directory and creates the
following files:
  - Project Perl module: `bug-mining/framework/core/Project/MyProject.pm`
  - Project build file: `bug-mining/framework/projects/MyProject/MyProject.build.xml`
  - Project repository: `bug-mining/project_repos/my-awesome-project.git`

The **project id** should **start with an upper-case letter** and should be
**short yet descriptive** (keep in mind that this id is used for commands such
as `defects4j checkout -p <project_id>`). The **project name** must not include
spaces, but can be hyphenated. For example, the project name for the Apache
Commons-Lang project, already included in Defects4J, is *commons-lang*, and its
project id is *Lang*.

2. Adapt the Perl module and the following properties if necessary:
    - Version control system (default is Git)
    - Location of the version control repository (default is
      `bug-mining/project_repos/<project_name>.git`)
    - Project layout (source and test directories)

**TODO: What exactly may need to be adapted (i.e., which functions) and how
should they be adapted? Maybe we could add some TODOS to identify which bits may need
to be checked/adapted, e.g., an example on how to adapt the perl module to SVN
and how to configure a different source/test directory.**

3. Adapt the Wrapper build file

**TODO: Perhaps we could add examples of common issues, e.g., how to add project
specific dependencies to the build file.**

Identifying candidate bugs (populating the `commit-db`)
-------------------------
1. Bug mining starts with identifying the issue tracker for the project you are
   interested in. Defects4j's bug-mining framework supports:
    - [google-code](https://code.google.com/) ('google' for short)
    - [jira](https://issues.apache.org/jira/)
    - [github](https://github.com)
    - [sourceforge](https://sourceforge.net/) ('sf' for short)

2. For trackers jira, github, google, but not sourceforge, create a directory
   `issues` to download the issue numbers:
```
mkdir bug-mining/issues
```

3. For trackers jira, github, google, but not sourceforge, use
   `download-issues.pl` to download all issues:
```
./download-issues.pl -g <tracker_name, e.g., jira> \
                        -t <tracker_project_id, e.g., LANG for the Apache Commons-Lang project> \
                        -o bug-mining/issues \
                        -f bug-mining/issues.txt
```

If a project has multiple bug trackers, use `merge-issue-numbers.pl` to combine
all issues:
```
./merge-issue-numbers.pl -f bug-mining/issues.txt
```
**TODO: in almost all cases we don't need merge-issue-numbers.pl.
Nevertheless, it should be fixed as it currently requires some __manual_input__**

4. Obtain the development history (commit logs) for the project:
```
git --git-dir=bug-mining/project_repos/<project_name>.git/ log > bug-mining/gitlog
```
**TODO: How to obtain the history for other VCS, e.g., SVN?**

5. Cross-reference the commit log with the issue numbers known to be bugs
   (saved in *issues.txt* in this example) by using `vcs-log-xref.pl`. The
   script requires a Perl regular expression that matches bug-fixing commits
   (e.g., issue numbers, keywords, etc.), e.g., `/(LANG-\d+)/mi` matches all
   bug-fixing commits of the Apache Commons-Lang project. Note that the regular
   expression has to capture the issue number. The script `merge-commit-db.pl`
   enumerates the output of `vcs-log-xref.pl` and outputs or updates the
   `commit-db` file:
```
./vcs-log-xref.pl -v <vcs name, i.e., git or svn> \
                     -e '<regular_expression>' \
                     -l bug-mining/gitlog \
                     -r bug-mining/project_repos/<project_name>.git \
                     -c './verify-bug-file.sh bug-mining/issues.txt' \
                     -f bug-mining/framework/projects/<project_id>/commit-db
./merge-commit-db.pl -f bug-mining/framework/projects/<project_id>/commit-db \
                        -g bug-mining/project_repos/<project_name>.git \
                        -t <tracker id, e.g., google, jira, github>
```
**TODO: merge-commit-db should only be required if someone is mining an existing
project ...**

These are the issue trackers, issue tracker project IDs, and regular expressions
previously used (Note that we manually built the `commit-db` for Chart):

| Project ID | Issue tracker | Issue tracker project ID | Regexp                    |
|------------|---------------|--------------------------|---------------------------|
| Chart      |               |                          |                           |
| Closure    | google        | closure-compiler         | `/issue.*(\d+)/mi`        |
| Lang       | jira          | LANG                     | `/(LANG-\d+)/mi`          |
| Math       | jira          | MATH                     | `/(MATH-\d+)/mi`          |
| Mockito    | github        | mockito/mockito          | `/Fix(?:es)?\s*#(\d+)/mi` |
| Time       | github        | JodaOrg/joda-time        | `/Fix(?:es)?\s*#(\d+)/mi` |
| Time       | sf            | joda-time                | `/\[.*?(\d+)/mi`          |

6. For tracker sourceforge (as we used for Time), note that due to a change in
   sourceforge's structure, bug ids which were once universal became project
   specific. Unfortunately the old, universal IDs are not available publicly for
   bulk query. Fortunately, the old ids web page will still redirect to the new
   IDs web page, allowing individual query. Provide `verify-bug-sf-tracker.sh
   <issue_tracker_project_id>` as the `-c` option to do this query on an
   individual basis.
   **TODO: `verify-bug-sf-tracker.sh` expects two arguments**

Analyzing the pre-fix and post-fix revisions of the candidate bugs
------------
1. Initialize all project revisions with `initialize-revisions.pl`. This script
   will identify the various directory layouts and run a sanity check on each
   candidate revision in `commit-db`:
```
./initialize-revisions.pl -p <project_id> -w bug-mining
```
Note: This step uses build-file analyzer to identify developer included &
excluded test sets.

**TODO: Is the build-file analyzer already integrated?**

Configuration for the analyzer may be needed (labeled TODO in
`initialize-revisions.pl`, arguments: `<path to build file>`,
`<path of generated output files>`, `<name of the build file>`). In the case
when analyzer produces incorrect result, please manually generalize patterns for
the test sets. Analyzer also provides quick insight on properties from
project-specific build files that are necessary for building
`project.build.xml`.
**TODO: The arguments of the analyzer seem to be `<working directory>` and
`<path to build file>` and not the ones mentioned above**
**TODO: Describe the build-file analyzer, which is called during the
initialize-revisions step, and integrate it into the framework**

2. Analyze all revisions with `analyze-project.pl`. This will identify
   suitable candidate bugs -- ones that compile and have a non-empty source diff:
```
./analyze-project.pl -p <project_id> \
                        -w bug-mining \
                        -g <tracker_name, e.g., jira, github, google, or sourceforge> \
                        -t <tracker_project_id, e.g., LANG>
```

3. If any revisions fail to build, inspect the project build script and error
   message and attempt to diagnose the issue. Some common problems are:
    - Missing dependencies (may require specified directory structure for
      dependency files). **TODO: what to do in this case?**
    - Containing outdated `build.xml` file due to migration to Maven (by
      default, Defects4J imports `build.xml` from each revision). **TODO how to
      identify the most recent build file?**
    - Missing `build.xml`: for Maven-based projects, edit `<project_id>.pm`
      (e.g., `MyProject.pm`) to run maven-ant plugin with overwrite option
      enabled. This will also solve the outdated build file issue stated above.
      For Gradle projects, such as the `Mockito` project, manually adapt a
      wrapper build file for all versions.
    - Note: please rerun `initialize_revision.pl` if there are changes
      introduced to `<project_id>.pm`.

4. If a build fails due to an empty test step, this is a common indication that
   there is a missing dependency on the test classpath (all tests fail due to
   the missing dependency). This can be confirmed by inspecting the
   corresponding file for the revision in the
   `bug-mining/framework/projects/<project_id>/failing_tests` folder. This file
   contains the stack trace for all tests that fail when executed against the
   "fixed" version of a class. If all tests fail due to a NoClassDefFoundError
   (or similar exception), then remove the `failing_test` file, ensure that the
   missing dependency is in place, and reanalyze the specific revisions by
   deleting the corresponding entries in `bug-mining/rev_pairs` and running
   `initialize-revisions.pl` with `-b <bug_id>`.

5. If a build fails due to running empty test set in "run.dev.tests" step, below
   is a list of common situations that might need to be addressed:
    - The directory structure or the property keys that contain directory
      structure information have changed for this failing version (or most of
      the versions afterwards). To address this, checkout the particular
      version, inspect its properties related to source/test directories, then
      adapt the changes in `<project_id>.build.xml`. Reanalyze the specific
      revision by deleting the corresponding entries in `bug-mining/rev_pairs`
      and running `initialize-revisions.pl` with `-b <bug_id>`.
    - Make sure the `all.manual.tests` fileset in `<project_id>.build.xml` is
      covering the tests listed in project version-specific build files.
    - Reanalyze the specific revisions by deleting the corresponding entries in
      `bug-mining/rev_pairs` and running `initialize-revisions.pl` with
      `-b <bug_id>`.

6. If particular revisions cannot be built, often due to dependencies that no
   longer exist, then they may be removed from the `commit-db`. It is
   recommended to keep a backup of the commit-db until the entire bug mining
   process is complete.

7. Upon completion of this stage, inspect all stack traces in the files that are
   generated in the `failing_tests` folder to ensure that tests failed for valid
   reasons, and not due to configuration errors. Failed assertions are generally
   valid test failures. Missing files or classes are generally due to a
   configuration issue.

**TODO: Describe the following review process, which may lead to several
   iterations of steps 1-7: check all entries in failing_tests and verify that
   1) no test classes are failing and 2) all failing tests are indeed broken
   tests that do not fail due to configuration issues.**

Reproducing bugs
-------------
1. Determine triggering tests with `get-trigger.pl`. This will determine the
   revisions in `commit-db` that have a test that can reproduce a fault:
```
./get-trigger.pl -p <project_id> -w bug-mining
```

2. Each reproducible fault has an entry in the `trigger_tests` directory:
```
ls bug-mining/framework/projects/<project_id>/trigger_tests
```

3. Manually analyze the stack trace for each fault and make sure this is a real
   fault reproduction, not a configuration issue (e.g., `CLASSPATH` errors or
   missing files). Each file in `trigger_tests` contains the stack trace for a
   reproduced fault:
```
vim bug-mining/framework/projects/<project_id>/trigger_tests/*
```
**TODO: not everyone knows how to exit vim. we might want to do a `cat`
instead**

4. If an invalid triggering test is encountered (e.g., due to a configuration
   issue), remove the corresponding line from the `trigger` file, fix the issue,
   and re-execute Step 1. If there is a corresponding file for the fixed
   revision in the failing_tests folder, then re-execute the analysis script
   (remember to delete corresponding entry in `rev_pairs`) for this bug as well.

**TODO: where is the "`trigger` file"?**
**TODO: Describe how to repeat steps 1-3 if an invalid triggering test is
encountered. Also, describe whether analyze-project needs to be rerun in case a
configuration issue is fixed.**

5. Determine relevant metadata (i.e., modified classes, loaded classes, and
   relevant tests) with `get-class-list.pl`. For each reproducible bug, this
   script determines the metadata, which will be promoted to the main database
   together with that bug:
```
./get-metadata.pl -p <project_id> -w bug-mining
```

Reviewing and isolating the bugs
------------------
1. Manually review the diff for each fault and make sure it is minimal. Every
   reproducible fault has an entry with the file name `<bid>.src.patch` in the
   `patches` directory:
```
ls -l bug-mining/framework/projects/<project_id>/patches/*.src.patch
./minimize-patch.pl -p <project_id> -b <bid> -w bug-mining
```
The default editor for patch minimization is [meld](https://meldmerge.org).
However, you may use other editors if you prefer.

Note that the patch is the *reverse* patch, i.e., patching the fixed version
with this patch will reintroduce the fault.

Promoting reproducible bugs to the main database
------------------
1. For each fault, if the diff is minimal (i.e., does not include features or
   refactorings), promote the fault to the main `Defects4J` database:
```
./promote-to-db.pl -p <project_id> -b <bid> -w bug-mining
```

**TODO: Augment the promote script: 1) reinvoke get-metadata.pl for all bugs for
which the patch was manually minimized and 2) store the issue tracker IDs in
Defects4J: add issue-tracker ID and URL as two new columns to the commit-db**

Note: Make sure to specify the `-b` option as the default is to promote all
bugs!

**TODO: does not `promote-to-db.pl` also have to update the official
`D4J/project_repos/defects4j-repos.zip` and uploaded it to
`http://people.cs.umass.edu/~rjust/defects4j/download/defects4j-repos.zip`?**

Glossary
--------------
Terms commonly used in Defects4J

- `PID`: *Project ID* (e.g., Lang, Math, Closure, etc.).
- `BID`: *Bug ID* (Defects4J enumerates all bugs per project, and the bug id is
         an integer. Historically, numerically higher BIDs are older bugs. As of
         *v1.3.0*, this is reversed -- with existing BIDs preserved).
- `VID`: *Version ID* ({BID}**b** refers to the **b**uggy and {BID}**f** refers
         to the **f**ixed version of a bug with the bug id {BID}.
- `VCS`: Version control system (e.g., git, mercurial, or subversion; all VCS
         abstractions in Defects4J inherit from Vcs.pm).
- `Rev ID`: A VCS-specific revision id (e.g., a git commit hash).
- `commit-db`: A csv file, per project, that maps each BID to the revision ids
               of the pre-fix and post-fix revision.

# TODO incorporate the following options
- `-p <project_id>`, e.g., `-p Codec`
- `-n <project_name>`, e.g., `-n commons-codec`
- `-b <bug_id>`, e.g., `-b 1`
- `-w <work_dir>`, e.g., `-w bug-mining`
- `-g <tracker_name>`, e.g., `-g jira`
- `-t <tracker_project_id>`, e.g., `-t CODEC`
- `-r <repository_url>`, e.g., `-r https://github.com/apache/commons-codec` or `-r bug-mining/project_repos/commons-codec.git`
- `-z <organization_id>`, e.g., `-z apache`
- `-q <query>`, e.g., `-q ___`
- `-u <tracker_uri>`, e.g., `-u https://issues.apache.org/jira/`
- `-l <fetching_limit>`, .e.g., `-l 50`
- `-f <issues_file>`, .e.g., `-f bug-mining/issues.txt`
- `-d <output_db_dir>`, .e.g., `-d ____`
- `-v <vcs_type>`, .e.g., `-v git`
- `-e <bug_matching_perl_regexp>`, .e.g., `-e /(LANG-\d+)/mi`
- `-c <command_to_verify>`, .e.g., `-c ____`
