Defects4J for Developers
================
This README provides backgroud and information useful for someone updating
and/or modifing the Defects4J system.  See README.md in this directory if
your primary interest is in using Defects4J for research.

How a user's Defects4J is initialized
-----------------
After cloning defects4j, the user runs the script `init.sh`. This script has
several steps:
- set up the test repositories
- set up the tools for mutation testing
- set up EvoSuite
- set up Randoop
- set up Gradle
- set up utility programs

Many of these items are copied from a protected directory on the Defects4j
web site:
* https://defects4j.org/downloads &nbsp; &nbsp; (HOST_URL below)

This directory can be accessed, from a CSE managed machine, at:
* /cse/web/research/defects4j/downloads

In the details below, the directory containing the user's clone of defects4j will be referred to as `BASE` and the defects4j download location will be referred to
as `HOST_URL`.

#### Setting up the test repositories
DIR_REPOS="$BASE/project_repos"
cd "$DIR_REPOS" && ./get_repos.sh

#### Setting up the tools for mutation testing
MAJOR_VERSION="1.3.4"
MAJOR_URL="https://mutation-testing.org/downloads"
MAJOR_ZIP="major-${MAJOR_VERSION}_jre7.zip"
cd "$BASE" && download_url_and_unzip "$MAJOR_URL/$MAJOR_ZIP" \
           && rm "$MAJOR_ZIP" \
           && cp major/bin/.ant major/bin/ant

#### Setting up EvoSuite
DIR_LIB_GEN="$BASE/framework/lib/test_generation/generation"
DIR_LIB_RT="$BASE/framework/lib/test_generation/runtime"
EVOSUITE_VERSION="1.1.0"
EVOSUITE_URL="https://github.com/EvoSuite/evosuite/releases/download/v${EVOSUITE_VERSION}"
EVOSUITE_JAR="evosuite-${EVOSUITE_VERSION}.jar"
EVOSUITE_RT_JAR="evosuite-standalone-runtime-${EVOSUITE_VERSION}.jar"
cd "$DIR_LIB_GEN" && download_url "$EVOSUITE_URL/$EVOSUITE_JAR"
cd "$DIR_LIB_RT"  && download_url "$EVOSUITE_URL/$EVOSUITE_RT_JAR"

#### Setting up Randoop
RANDOOP_VERSION="4.2.5"
RANDOOP_URL="https://github.com/randoop/randoop/releases/download/v${RANDOOP_VERSION}"
RANDOOP_ZIP="randoop-${RANDOOP_VERSION}.zip"
(cd "$DIR_LIB_GEN" && download_url_and_unzip "$RANDOOP_URL/$RANDOOP_ZIP")

#### Setting up Gradle
DIR_LIB_GRADLE="$BASE/framework/lib/build_systems/gradle"
cd "$DIR_LIB_GRADLE"
GRADLE_DISTS_ZIP=defects4j-gradle-dists.zip
GRADLE_DEPS_ZIP=defects4j-gradle-deps.zip
download_url $HOST_URL/$GRADLE_DISTS_ZIP
download_url $HOST_URL/$GRADLE_DEPS_ZIP

#### Setting up utility programs
BUILD_ANALYZER_VERSION="0.0.1"
BUILD_ANALYZER_JAR=build-analyzer-$BUILD_ANALYZER_VERSION.jar
BUILD_ANALYZER_URL="https://github.com/jose/build-analyzer/releases/download/v$BUILD_ANALYZER_VERSION/$BUILD_ANALYZER_JAR"
BUILD_ANALYZER_JAR_LOCAL="analyzer.jar"
cd "$BASE/framework/lib" && download_url "$BUILD_ANALYZER_URL"




ASF update procedure:
* Since the two repos for Lang and the two repos for Math were identical modulo commit hashes, this was mostly a scripting exercise to update all relevant files.
* Ryan's script is here (I think):
https://github.com/rjust/defects4j/blob/java-11-compatibility/upgrade/scripts/update_hashes.py
* The test_verfiy_bugs.sh script is essentially the test oracle -- if it passes, the update was successful.
* I went through the exercise doing the same thing for Chart last night (though this is updating from an SVN repo to a Git repo); my script is here:
https://github.com/rjust/defects4j/blob/Svn-to-git/framework/util/svn-git.sh;
this requires a few more tweaks because the SVN and Git repo are not 100% identical, but the update process is the same.
* Note that these scripts will probably not make it into the main branch; they only encode the update procedure, which makes it easier to review and verify the individual steps. I don't think these scripts are reusable and worth keeping around.
* Popping up a few levels, you can ignore these repository updates as they have no implications for Java-11 compatibility -- the source code in the working directory is the same no matter the underlying repository. As long as you are using the java-11-compatibility branch and running init.sh, you will have the correct repositories available.

Git details and defects4j-repos.zip (defects4j-repos-v3.zip):
* The project_repos directory is populated by running the get_repos.sh script; the repos are not included for space reasons.
* All project repos are archived in a file
(https://github.com/rjust/defects4j/blob/java-11-compatibility/project_repos/get_repos.sh#L6)
* Each repository in that archive (name.git folder) is created by running git clone --bare <URL>; the README in the archive lists the URLs.
* These name.git folders are essentially the same as the .git folder in a working directory.
    - For example (1) git clone https://github.com/rjust/defects4j and
(2) git clone --bare https://github.com/rjust/defects4j --> (1) defects4j/.git and (2) defects4j.git both provide the full repo history.
* Ideally, we would simply run git pull on each of the name.git repositories to update the version control history every once in a while and update the archive on the website. This no longer worked for Lang and Math because the history had been rewritten; we should be able to update all repositories when we release version 3, but again this is independent of the Java-11 compatibility issues.



Intended process:
* The D4J website provides an archive with clones of all project repositories (to avoid cloning from multiple sources and to make sure artifacts are reliably available).
* We expected newer versions of this archive to be a strict superset of a previous version (either more projects or more commits for a given project), and hence did not version the archive file.
* Whenever new bugs are mined for an existing project, the archive is updated (essentially just a pull to update the D4J clone).
* Whenever new bugs are mined for a new project, a clone for the new project is added to the archive.

Changes in Apache Software Foundation (ASF) projects and subsequent process changes:
* The ASF rewrote the entire version control history for some of their projects, including Lang and Math.
* The commit contents are identical, but the commit hashes are different.
* This didn't cause any problems since D4J ships its own repository clones, but it meant that we couldn't add new bugs.
* Version 3 seemed like a good time to update these repositories because version 3 involves a number of major changes.
* My understanding of Ryan's update procedure (for Lang and Math):
   - Set up two local clones of the "same" repository (D4J clone and ASF clone).
   - Each D4J bug references two commit hashes in D4J clone (buggy and fixed revision IDs).
   - For each D4J bug find the corresponding commit hashes in ASF clone by grepping for the commit message (which mentions an issue id) and comparing the commit contents.
   - Replace all commit hashes in active-bugs.csv, deprecated-bugs.csv, and commit-db
   - Replace all commit hashes for additional files (e.g., failing-tests)
   - Update the D4J archive to include the ASF clones
   - Version the new archive as v3 (to maintain backwards compatibility)
   - Update the get-repos.sh script to download the new archive



Setting up Defects4J
================

Requirements
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

| Change                                  | `major` | `minor` | `patch` |
|-----------------------------------------|:-------:|:-------:|:-------:|
| Addition/Deletion of bugs               |    X    |         |         |
| New/upgraded internal or external tools |         |    X    |         |
| Fixes and documentation changes         |         |         |    X    |

License
---------
MIT License, see [`license.txt`](https://github.com/rjust/defects4j/blob/master/license.txt) for more information.
