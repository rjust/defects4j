# Overview of the bug-mining process

1. Initialize a bug-mining working directory and configure a project for bug mining.

2. Identify candidate bugs by cross-referencing the project's version control
   history with the project's bug tracker.

3. Analyze the pre-fix and post-fix revisions of the candidate bugs:
   Identify all bugs whose pre-fix and post-fix revisions are compilable and
   testable.

4. Reproduce bugs: Run the project's tests to verify that each bug can be
   reliably reproduced with at least one bug-triggering test that fails on the
   pre-fix and passes on the post-fix revision.

5. Review and isolate bugs: Manually minimize the bug if necessary (i.e.,
   eliminate features or refactorings).

6. Promote all reproducible minimized bugs to the main `Defects4J` database!



## Initializing the working directory, configuring the project, and identifying candidate bugs

Suppose we want to mine reproducible bugs from the
[Apache Commons Codec](https://commons.apache.org/proper/commons-codec/)
project.

First, define a working directory for the *bug-mining* process, e.g.:

```bash
WORK_DIR="bug-mining"
```

All mined data, i.e., commits, issues, metadata of the project will be written
to this temporary working directory. (The final step of this step-by-step tutorial
promotes all metadata to the `Defects4J` database.)

Next, define the general properties of the project.
For the [Apache Commons Codec](https://commons.apache.org/proper/commons-codec/)
project, these are:

```bash
PROJECT_ID="Codec"
PROJECT_NAME="commons-codec"
REPOSITORY_URL="https://github.com/apache/commons-codec.git"

ISSUE_TRACKER_NAME="jira"
ISSUE_TRACKER_PROJECT_ID="CODEC"
BUG_FIX_REGEX="/(CODEC-\d+)/mi"
```

- The **project id** (i.e., `PROJECT_ID`) should **start with an upper-case letter**
  and should be **short yet descriptive** (keep in mind that this id is used for
  commands such as `defects4j checkout -p <PROJECT_ID>`).
- The **project name** (`PROJECT_NAME`) must not include spaces, but can be
  hyphenated. For example, the project name for the Apache Commons-Lang project,
  already included in Defects4J, is *commons-lang*, and its project id is *Lang*.
- The **issue tracker id** (`ISSUE_TRACKER_NAME`) identifies the issue tracker
  for the project you are interested in. Defects4j's bug-mining framework
  supports the following issue trackers:
    - [google-code](https://code.google.com/) ('google' for short)
    - [jira](https://issues.apache.org/jira/)
    - [github](https://github.com)
    - [sourceforge](https://sourceforge.net/) ('sf' for short)
- The **issue tracker project id** (`ISSUE_TRACKER_PROJECT_ID`) is the project
  identifier used in the issue tracker. For example, the issue tracker project
  id for the Apache Commons-Lang project is *LANG*.
- The **bug fix regex** is a Perl regular expression that matches bug-fixing
  commits (e.g., issue numbers, keywords, etc.), e.g., `/(LANG-\d+)/mi` matches
  all bug-fixing commits of the Apache Commons-Lang project. Note that the
  regular expression has to capture the issue number.

The following table reports the issue trackers, issue tracker project IDs, and
regular expressions previously used in `Defects4J` (note that we manually built
the `active-bugs.csv` for Chart):

| Project ID | Issue tracker | Issue tracker project ID | Regexp                    |
|------------|---------------|--------------------------|---------------------------|
| Chart      |               |                          |                           |
| Closure    | google        | closure-compiler         | `/issue[^\d]*(\d+)/mi`    |
| Lang       | jira          | LANG                     | `/(LANG-\d+)/mi`          |
| Math       | jira          | MATH                     | `/(MATH-\d+)/mi`          |
| Mockito    | github        | mockito/mockito          | `/Fix(?:es)?\s*#(\d+)/mi` |
| Time       | github        | JodaOrg/joda-time        | `/Fix(?:es)?\s*#(\d+)/mi` |
| Time       | sf            | joda-time                | `/\[.*?(\d+)/mi`          |


### Initialize project and collect issues

Once all properties have been defined, the
`initialize-project-and-collect-issues.pl` should be executed as:

```bash
./initialize-project-and-collect-issues.pl -p $PROJECT_ID \
                                           -n $PROJECT_NAME \
                                           -w $WORK_DIR \
                                           -r $REPOSITORY_URL \
                                           -g $ISSUE_TRACKER_NAME \
                                           -t $ISSUE_TRACKER_PROJECT_ID \
                                           -e $BUG_FIX_REGEX
```

This script performs 3 tasks:

1. Configures a new project for `Defects4J`. It automatically initializes a
   temporary *bug-mining* working directory (`$WORK_DIR`) and creates the
   following files:
   - Project Perl module: `$WORK_DIR/framework/core/Project/$PROJECT_ID.pm`
   - Project build file: `$WORK_DIR/framework/projects/$PROJECT_ID/$PROJECT_ID.build.xml`
   - Project repository: `$WORK_DIR/project_repos/$PROJECT_NAME.git`

2. Collects all data of each issue in the project issue tracker. The data of
   each issue is written to `$WORK_DIR/issues` and all issues ids are written to
   `$WORK_DIR/issues.txt`.

3. Performs a cross-reference of commit log and the issue ids, and creates a
   `active-bugs.csv` with all commits hashes for all issues ids that have been
   reported in the issue tracker.



## Analyzing the pre-fix and post-fix revisions of the candidate bugs

1. Initialize all project revisions with `initialize-revisions.pl`. This script
   will identify the various directory layouts and run a sanity check on each
   candidate revision in `active-bugs.csv`:

```bash
./initialize-revisions.pl -p $PROJECT_ID -w $WORK_DIR
```

If the project under mining uses either [Apache Ant](https://ant.apache.org/) or
[Apache Maven](https://maven.apache.org/) as its build system this script should
run with no problems. However, if the project you are mining require additional
dependencies or different classpaths to compile/run than ones pre-defined then,
the Perl module (`$WORK_DIR/framework/core/Project/$PROJECT_ID.pm`) and/or the
wrapper build file
(`$WORK_DIR/framework/projects/$PROJECT_ID/$PROJECT_ID.build.xml`)
might need to be manually adapted.

`initialize-revisions.pl` script uses a utility java program called
[build-file analyzer](https://github.com/jose/build-analyzer) to identify
the list of developer included & excluded test sets and properties of the
project, such as, the compilation targets, the source and test directory, and
the source and test classes directory. The metadata extracted by the
`build-file analyzer` is written to
(`$WORK_DIR/framework/projects/$PROJECT_ID/analyzer_output/<bug_id>`). This
metadata might be useful to updated the Perl module
`$WORK_DIR/framework/core/Project/$PROJECT_ID.pm` and/or the wrapper build file
`$WORK_DIR/framework/projects/$PROJECT_ID/$PROJECT_ID.build.xml` if the build of
a revision fails.

2. Analyze all revisions with `analyze-project.pl`. This script will identify
   suitable candidate bugs -- ones that compile and have a non-empty source
   diff:

```bash
./analyze-project.pl -p $PROJECT_ID \
                     -w $WORK_DIR \
                     -g $ISSUE_TRACKER_NAME \
                     -t $ISSUE_TRACKER_PROJECT_ID
```


### Tips in case a revision fails to build

1. If any revisions fail to build, inspect the project build script
   (`$WORK_DIR/framework/projects/$PROJECT_ID/$PROJECT_ID.build.xml`) and the
   error message(s) and attempt to diagnose the issue. Some common problems are:
    - Missing dependencies (may require specified directory structure for
      dependency files).
    - For Gradle projects, such as the `Mockito` project, manually adapt a
      wrapper build file for all versions.
    - Note: please rerun `initialize_revision.pl` if there are changes
      introduced to `$PROJECT_ID.pm`.

2. If a build fails due to an empty test step, this is a common indication that
   there is a missing dependency on the test classpath (all tests fail due to
   the missing dependency). This can be confirmed by inspecting the
   corresponding file for the revision in the
   `$WORK_DIR/framework/projects/$PROJECT_ID/failing_tests` folder. This file
   contains the stack trace for all tests that fail when executed against the
   "fixed" version of a class. If all tests fail due to a NoClassDefFoundError
   (or similar exception), then remove the `failing_test` file, ensure that the
   missing dependency is in place, and reanalyze the specific revisions by
   deleting the corresponding entries in `$WORK_DIR/rev_pairs` and running
   `initialize-revisions.pl` with `-b <bug_id>`.

3. If a build fails due to running empty test set in "run.dev.tests" step, below
   is a list of common situations that might need to be addressed:
    - The directory structure or the property keys that contain directory
      structure information have changed for this failing version (or most of
      the versions afterwards). To address this, checkout the particular
      version, inspect its properties related to source/test directories, then
      adapt the changes in `$PROJECT_ID.build.xml`. Reanalyze the specific
      revision by deleting the corresponding entries in `$WORK_DIR/rev_pairs`
      and running `initialize-revisions.pl` with `-b <bug_id>`.
    - Make sure the `all.manual.tests` fileset in `$PROJECT_ID.build.xml` is
      covering the tests listed in project version-specific build files.
    - Reanalyze the specific revisions by deleting the corresponding entries in
      `$WORK_DIR/rev_pairs` and running `initialize-revisions.pl` with
      `-b <bug_id>`.

4. If particular revisions cannot be built, often due to dependencies that no
   longer exist, then they may be removed from the `active-bugs.csv`. It is
   recommended to keep a backup of the active-bugs.csv until the entire bug mining
   process is complete.

5. Upon completion of this stage, inspect all stack traces in the files that are
   generated in the `$WORK_DIR/framework/projects/$PROJECT_ID/failing_tests`
   folder to ensure that tests failed for valid reasons, and not due to
   configuration errors. Failed assertions are generally valid test failures.
   Missing files or classes are generally due to a configuration issue.



## Reproducing bugs

1. Determine triggering tests with the `get-trigger.pl` script. This will
   determine the revisions in `active-bugs.csv` that have a test that can reproduce a
   fault:

```bash
./get-trigger.pl -p $PROJECT_ID -w $WORK_DIR
```

Each reproducible fault has an entry with the name `<bid>` in the
`$WORK_DIR/framework/projects/$PROJECT_ID/trigger_tests` directory. Each file in
this directory contains the stack trace for a reproduced fault.

- Manually analyze the stack trace for each fault and make sure this is a real
  fault reproduction, not a configuration issue (e.g., `CLASSPATH` errors or
  missing files). In case there are errors related to configurations issues, the
  Perl module `$WORK_DIR/framework/core/Project/$PROJECT_ID.pm` and/or the
  wrapper build file
  `$WORK_DIR/framework/projects/$PROJECT_ID/$PROJECT_ID.build.xml` might need to
  be manually fixed and the `analyze-project.pl` script rerun.

- If an invalid triggering test is encountered (e.g., due to a configuration
  issue), remove the corresponding line from the `$WORK_DIR/trigger` file, fix
  the issue, and re-execute Step 1. If there is a corresponding file for the
  fixed revision in the `failing_tests` folder, then re-execute the analysis
  script (remember to delete corresponding entry in the `$WORK_DIR/rev_pairs`
  file) for this bug as well.


2. Determine relevant metadata (i.e., modified classes, loaded classes, and
   relevant tests) with the `get-metadata.pl` script. For each reproducible bug,
   this script determines the metadata, which will be promoted to the main
   database together with that bug. (Note that this script calls
   [diffstat](https://invisible-island.net/diffstat/) tool to determine the list
   of modified files in patch. Please make sure `diffstat` is installed and in
   your `PATH`.)

```bash
./get-metadata.pl -p $PROJECT_ID -w $WORK_DIR
```


## Reviewing and isolating the bugs

Manually review the diff for each fault and make sure it is minimal. Every
reproducible fault has an entry with the file name `<bid>.src.patch` in the
`$WORK_DIR/framework/projects/$PROJECT_ID/patches` directory:

```bash
./minimize-patch.pl -p $PROJECT_ID -w $WORK_DIR -b <bid>
```

The default editor for patch minimization is [meld](https://meldmerge.org).
However, you may use other editors if you prefer. 
[The following link](http://joaquin.windmuller.ca/2011/11/16/selectively-select-changes-to-commit-with-git-or-imma-edit-your-hunk) 
explains how to manually edit patches. Keep in mind that some editors, 
such as Atom, will automatically remove the spaces at the end of the file, 
causing the patch file to be corrupted.

**Please read the [Patch Minimization Guide.md](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/Patch-Minimization-Guide.md)**
before performing patch minimization. This guide provides detailed documentation for the patch minimization process.

Note that the patch is the *reverse* patch, i.e., patching the fixed version
with this patch will reintroduce the fault.

Once a patch is manually minimized, the script performs a few sanity checks: (1)
whether the source code and the test cases still compile and (2) whether the
list of triggering test cases is still the same. The script also recomputes all
metadata by rerunning the `get-metadata.pl` script if the patch has been
minimized.

To restore the original patch, you may delete the corresponding patch in the `patch` 
directory and re-run `./initialize-revision.pl -p <project> -w <working-directory> -b <bug.id>`

## Promoting reproducible bugs to the main database

For each fault, if the diff is minimal (i.e., does not include features or
refactorings), promote the fault to the main `Defects4J` database:

```bash
./promote-to-db.pl -p $PROJECT_ID \
                   -w $WORK_DIR \
                   -r $WORK_DIR/project_repos/$PROJECT_NAME.git \
                   -b <bid>
```

Note: Make sure to specify the `-b` option as the default is to promote all
bugs!



## Glossary

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
- `active-bugs.csv`: A csv file, per project, that maps each BID to the revision ids
  of the pre-fix and post-fix revision.
- working directory: where the buggy or fixed version of the code appears.
  The `checkout` command creates a working directory.


## Troubleshooting

* If you encounter the following error when running `./initialize-project-and-collect-issues.pl`:

   ```
  Can't locate JSON/Parse.pm in @INC (you may need to install the JSON::Parse module)
   ```
   - Make sure that you have installed all of the perl dependencies listed in [cpanfile](https://github.com/rjust/defects4j/blob/master/cpanfile). As mentioned in the top-level [README](https://github.com/rjust/defects4j/blob/master/README.md), these can automatically installed by running: `cpanm --installdeps .`
   
## Limitations of the bug-mining framework

- Although some scripts in the bug-mining framework are agnostic to the version
  control system used by a project and even support different version control
  systems, there are some other scripts that are Git dependent.
- If a project uses more than one issue tracker only one can be mined.
- Although the `Mockito` project in `Defects4J` database uses
  [Gradle](https://gradle.org/) as its build system, the current bug-mining
  framework only supports [Apache Ant](https://ant.apache.org/) and
  [Apache Maven](https://maven.apache.org/).
