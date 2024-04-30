Defects4J for Developers
================
This README provides background and information useful for someone updating
and/or modifing the Defects4J system.  See README.md in this directory if
your primary interest is in using Defects4J for research.

How a user's Defects4J is initialized
----------------
After cloning defects4j, the user runs the script `init.sh`. This script has
several steps:
- set up the project repositories
- set up the tools for mutation testing
- set up EvoSuite
- set up Randoop
- set up Gradle
- set up utility programs

The project repositories and the Gradle tools are copied from a protected
directory on the Defects4J web site:  
https://defects4j.org/downloads

This directory can be accessed, from a CSE managed machine, at:  
/cse/web/research/defects4j/downloads

In the details below, the directory containing the user's clone of defects4j
will be referred to as `BASE` and the defects4j download location will be
referred to as `HOST_URL`.

### Setting up the project repositories
The project\_repos directory (`$BASE/project_repos`) is populated by running
the `get_repos.sh` script in that directory; the repos are not included for
space reasons.  All project repos are archived in the file:  
`$HOST_URL/defects4j-repos-v3.zip`

Each repository in that archive (name.git folder) is created by running
`git clone --bare <URL>;` the README in the archive lists the URLs.
These name.git folders are essentially the same as the .git folder in a working directory.

### Setting up the tools for mutation testing
The tools are downloaded from:  
https://mutation-testing.org/downloads

### Setting up EvoSuite
EvoSuite is downloaded from:  
https://github.com/EvoSuite/evosuite/releases/download

### Setting up Randoop
Randoop is downloaded from:  
https://github.com/randoop/randoop/releases/download

It should be noted that the `init.sh` script currently gets Randoop version 4.2.5
which is about three years old.  At some point we should upgrade to a newer
version; the current version is 4.3.2.

### Setting up Gradle
Gradle is downloaded from `HOST_URL`.  As the reproducible bugs in the defect4j
project repositories are several years old, we must use an older version of gradle
to build the code defects in the Mockito repository. Version 2.x of Defects4J
used Gradle version 2.2.1. The current version (3.x) of Defects4J uses Gradle version 4.9.

### Setting up utility programs
These programs are downloaded from:  
https://github.com/jose/build-analyzer/releases/download

Notes
----------------
#### Testing
The test\_verfiy\_bugs.sh script is essentially the test oracle -- if it passes,
the updates/changes were successful.
#### Project Repos
* Ideally, we would simply run git pull on each of the name.git repositories to
update the version control history every once in a while and update the archive
on the website. Sometimes this does not work as the git history for the repo has
been rewritten. We should be able to update all repositories at some point after we release version 3.
* The D4J website provides an archive with clones of all project repositories (to avoid cloning from multiple sources and to make sure artifacts are reliably available).
* We expected newer versions of this archive to be a strict superset of a previous version (either more projects or more commits for a given project), and hence did not version the archive file.
* Whenever new bugs are mined for an existing project, the archive is updated (essentially just a pull to update the D4J clone).
* Whenever new bugs are mined for a new project, a clone for the new project is added to the archive.

Requirements (from README.md)
----------------
 - Java 11
 - Git >= 1.9
 - SVN >= 1.8
 - Perl >= 5.0.12

Defects4J version 2.x required Java 1.8.
Defects4J version 1.x and 0.x required Java 1.7.


#### Java version
All bugs have been reproduced and triggering tests verified, using the latest
version of Java 11.
Using a different version of Java might result in unexpected failing tests on a fixed
program version. 


Implementation details
----------------------

Documentation for any script or module is available as
[HTML documentation][htmldocs].

[htmldocs]: http://defects4j.org/html_doc/index.html

The directory structure of Defects4J is as follows:

    defects4j
       |
       |--- project_repos:     The version control repositories of the provided projects.
       |
       |--- major:             The Major mutation framework.
       |
       |--- framework:         Libraries and executables of the core, test execution,
           |                   and bug-mining frameworks.
           |
           |--- bin:           Command line interface to Defects4J.
           |
           |--- bug-mining:    Bug-mining framework.
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
           
Versioning information
----------------------
Defects4J uses a semantic versioning scheme (`major`.`minor`.`patch`):
~~~text
| Change                                  | `major` | `minor` | `patch` |
|-----------------------------------------|:-------:|:-------:|:-------:|
| Addition/Deletion of bugs               |    X    |         |         |
| New/upgraded internal or external tools |         |    X    |         |
| Fixes and documentation changes         |         |         |    X    |
~~~

Miscellaneous Notes
-------------------

#### Build_files

'build_files' associated with the buggy version are not used; both buggy and fixed use the fixed version.
I believe the buggy versions are are generated and only used during bug-mining.
They should probably be removed and we should add an issue for not propagating these files from bug-mining to the
final data set, if this is still the case.

Related, the test patches (<bid>.test.patch) stored in the repo are also not used. I think we
should remove these as well. Source patches are manually minimized, but test patches are
not -- these can be easily regenerated by running a diff between the buggy and fixed revisions.