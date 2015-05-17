Overview of the process
----------------------------
1. Finding candidate revisions by cross-referencing a development commit log with an issue tracker database.
2. Project setup: Making sure that the candidate revisions are compilable and conform to path expectations of `defects4j`.
3. Reproducing faults: Running tests to verify that the bug can be reproduced reliably with a test that fails before the fix
   and passes afterwards.
4. Reviewing revisions and promoting to main database: Manually determine whether the patch is a bug fix or has other things
    (e.g., features) mixed in. If it is only a bug fix, promote it to the main `defects4j` database!

The candidate commit database: `commit-db`
-------------------------
1. Bug mining starts with finding the issue tracker to the project you're interested in.
   Defects4j mining framework supports google-code, JIRA (defaulting to apache), github,
   and sourceforge bug trackers.
2. Make a directory as the working directory for the bug mining process.
    - `mkdir working`
    - `cd working`
3. Make a directory for the project you are obtaining bugs for inside `working`,
   the names in use for defects4j projects are `Chart`, `Closure`, `Math`, `Lang`, and `Time`.
    - `mkdir Closure`
    - `cd Closure`
4. (For trackers JIRA, github, google-code, but not sourceforge) Make a directory to download
   issue numbers.
    - `mkdir issues`
5. (For trackers JIRA, github, google-code, but not sourceforge) Use the `download-issues.pl` script to download issues. The `merge-issue-numbers.pl` script can help
   if a project has multiple trackers:
    - `../../bug-mining/download-issues.pl google -p closure-compiler -o issues | ../../bug-mining/merge-issue-numbers.pl -f issues.txt`
6. Obtain the development history (commit log) for the project:
    - `git --git-dir=../../../project_repos/closure-compiler.git/ log > gitlog`
7. Cross-reference the commit log with issue numbers known to be bugs (saved in `issues.txt` in our example).
   The script `vcs-log-xref.pl` helps with this task. You will need to find a Perl regular expression
   that matches a string and an issue number that developers commonly use to identify bug-fixing commits.
   This regular expression should 'capture' the issue number. The auxiliary script `merge-commit-db.pl`
   will number the output of `vcs-log-xref.pl`, and will output or update the `commit-db`.
   
   These are the regular expressions we used:

   | Project   | Regexp              |
   |-----------|---------------------|
   | Chart     | None - `commit-db` built manually |
   | Closure   | `/issue.*?(\d+)/mi` |
   | Lang      | `/LANG-(\d+)/mi`    |
   | Math      | `/MATH-(\d+)/mi`    |
   | Time (github)      | `Fix(es)?\s*#(\d+) /mi` |
   | Time (sf) | `\[.*?(\d+)/mi` e.g., matches [298342]|
   -  `../../bug-mining/vcs-log-xref.pl -b '/issue.*(\d+)/mi' -l gitlog -r ../../../project_repos/closure-compiler.git/ -c '../../bug-mining/verify-bug-file.sh issues.txt ' |
        ../../bug-mining/merge-commit-db.pl -f commit-db`
8. (For sourceforge) Note that if you are using a sourceforge tracker (as we did with Time), due to a change in sourceforge's
   structure, bug ids which were once universal became project specific. Unfortunately the old, universal ids are not available
   publicly for bulk query. Fortunately, the old ids webpage will still redirect to the new ids webpage, allowing individual
   query. Provide the script `verify-bug-sf.sh <project-id>` as the `-c` option to do this query on an individual basis.


Project setup
------------
1. Run the script `initialize-revisions.pl`
    - From `working`, run:
    - `../bug-mining/initialize-revisions.pl -p Closure -w .`
   This will identify the various directory layouts and run a sanity check on each revision in `commit-db`.
2. Run the script `analyze-project.pl`
    - `../bug-mining/analyze-project.pl -p Closure -w .`
   This will identify suitable candidates, ones that compile and have a non-empty source diff.

Reproducing faults
-------------
1. Run the script `get-trigger.pl`
    - From `working`, run:
    - `../bug-mining/get-trigger.pl -p Closure -w .`
   This will determine the revisions in `commit-db` that have a test that can demonstrate a bug.
2. Run the script `get-class-list.pl`
    - `../bug-mining/get-class-list.pl -p Closure -w .`
   This will determine the modified classes for revisions with a reproducible fault, and also the
    list of classes loaded during the execution of the triggering test.

Reviewing revisions and promoting to main database
------------------
1. Reproducible faults will have an entry in the `trigger_tests` directory.
    - `ls Closure/trigger_tests`
2. View the stack trace for each fault (manually), then make sure this is a real bug reproduction, not a configuration issue,
    or one related to `CLASSPATH` or missing files. The stack trace for each reproduced fault will be in a file in `trigger_tests`.
    - `vim Closure/trigger_tests/101`
3. View the diff for each fault (can be found with the corresponding number in `patches`).
    - `vim Closure/patches/101.src.patch`
   Note the patch is the *reverse* patch, i.e., patching the fixed revision with this patch would reintroduce the bug.
4. If reviewers determine that this bug fix is minimal, i.e., does not include refactorings, additional features, specification
   changes, or any other change that would cause test failure due to an unrelated reasone, promote the fault to the
   main `defects4j` database:
   - `../bug-mining/promote-to-directory.pl -p Closure -w . -v 101`
   - Make sure to specify the `-v` option, the default is to promote all found bugs!


