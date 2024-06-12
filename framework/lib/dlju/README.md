# do-like-junit

`do-like-junit` (or `dlju`) is a tool that extracts test information from build processes
of a given Java project, and extracts command(s) to run the project's tests directly.

`do-like-junit` supports projects built with

 - Apache Ant
 - Apache Maven

The `dlju` executable (in `bin/dlju`) specifically works with `defects4j` projects.

## Dependencies

Python 3 is required, as well as [do-like-javac](https://github.com/kelloggm/do-like-javac)
(or `dljc`) and `defects4j` on your path.

You should also have

 - the build tool of choice, and
 - any project dependencies

installed as well.

## Installation

After cloning this repo and making sure you have the above dependencies, you can add a symlink to the location of the `bin/dlju`
executable somewhere on your path, for example:

```
ln -s /path/to/dlju $HOME/bin/dlju
```

## Running

Suppose we want to analyze the build system of Lang, bug 1 (fixed version). Run the following in the terminal (does not have to be in any particular directory):

```
dlju Lang 1f ant compile test
```

This checks out Lang, version 1f, to a working directory `/tmp/d4j/Lang-1f`, and runs
`ant clean`, the runs `ant compile` and `ant test` using `dljc`. An executable file called `run_junit`
is produced in the working directory. Then you can test if test run extraction was successful:

```
$ cd /tmp/d4j/Lang-1f
$ ./run_junit
JUnit version 4.10
..........
Time: 0.034

OK (10 tests)

JUnit version 4.10
.............
Time: 0.01

OK (13 tests)

JUnit version 4.10
.......................................................
Time: 0.024

OK (55 tests)
# etc
```

You should see output similar to the above.

In general, to run on any `defects4j` project, use

```
dlju <project_name> <project_version> <build_command> <compile_target> <test_target>
```

### Troubleshooting

If a run fails, you can inspect the `dljc` build logs, which will be in `/tmp/d4j/<project_name>-<project_version>/<build_command>.compile.logs` and `/tmp/d4j/<project_name>-<project_version>/<build_command>.test.logs`.

#### Common issue: package <package name> does not exist

For example, this build output (from `/tmp/d4j/Lang-1f`)

```
[javac] /private/tmp/d4j/Lang-1f/src/test/java/org/apache/commons/lang3/CharSequenceUtilsTest.java:21: error: package org.junit does not exist
[javac] import static org.junit.Assert.assertNotNull;
```

This most likely indicates that the `build.properties` file in the working
directory either

 - doesn't exist,
 - does exist, but doesn't point to the actual locations of build dependencies such as `junit`.

#### Common issue: Apache Rat causes build to fail

Sometimes, the compile and test log directories and files can trip up the maven rat plugin,
which assumes that these log directories and files are unlicensed. As a workaround,
you can manually change the `dlju` executable so that it outputs logs inside the
build directory for the project, or you can add `<build_command>.test.logs` and
`<build_command>.compile.logs` to the project's `.gitignore`.


# dljc_to_argfile

Takes the `javac.json` output from [do-like-javac](https://github.com/kelloggm/do-like-javac)
and turns it into an argfile that you can give to `javac`.

## Requirements

Requires

 - Python 3
 - either Mac OS X or Linux
 - `dljc` (the `do-like-javac` executable) on your path

## How to Use

```
usage: javac_to_argfile.py [-h] [-o OPTIONS] [-c CLASSES] [-d ARGFILES_DIR]
                           [-n] [-b BUILD_SCRIPT] [-N]
                           file

Turns the json javac output from do-like-javac into a javac argfile

positional arguments:
  file                  The location of the json do-like-javac output to turn
                        into an argfile

optional arguments:
  -h, --help            show this help message and exit
  -o OPTIONS, --options OPTIONS
                        Name/location of the options file. Defaults to
                        "options"
  -c CLASSES, --classes CLASSES
                        Name/location of the classes file to be output.
                        Defaults to "classes"
  -d ARGFILES_DIR, --argfiles-dir ARGFILES_DIR
                        The directory to put all generated argfiles. By
                        default, if there is only one javac call in the json
                        file, it puts the argfiles into the current directory.
                        However, if there are multiple javac calls, it will
                        default to putting them into a directory called all-
                        argfiles, which will be in the current directory,
                        unless you turn on the flag --no-dirs.
  -n, --no-dir          If this option is provided and no --argfiles-dir is
                        specified, then it will always output all argfiles
                        into the current directory, even if there are multiple
                        javac calls. Note that if --argfiles-dir/-d is given,
                        then this option is ignored.
  -b BUILD_SCRIPT, --build-script BUILD_SCRIPT
                        If provided, this will automagically generate a shell
                        script to run that will execute all of the javac
                        commands found in the provided javac.json file. Even
                        if the option isn't provided, if there is more than
                        one javac call in the javac json file, it will by
                        default call it build_all.sh, and it will be placed
                        either in the argfiles directory (with no -n/--no-dir
                        specified) or in the current directory (with -n/--no-
                        dir specified). To turn off this default behavior, use
                        the option -N/--no-build-script.
  -N, --no-build-script
                        If -N/--no-build-script is given and -b/--build-script
                        is not specified, then javac_to_argfile.py will not
                        attempt to automagically generated a shell script that
                        runs all of the javac commands. If -b/--build-script
                        is specified, then this option is ignored.
```

### Overview of features
Note that paths containing spaces are always wrapped in double-quotes.

#### Generation of argfiles

For the kth `javac` call that is encoded in the `javac.json` file, `javac_to_argfile.py`
generates two files: one named by default `optionsk` and the other named `classesk`,
which contain the `javac` switches and sourcefiles respectively. If there is only
one `javac` call in the `javac.json` file given, these files are named `options`
and `classes` instead.

#### Generation of a script for running the javac calls
This script, which is by default named `build_all.sh` (which can be changed
using the option `-b/--build-script`), will create any directories necessary
and call `javac` on the generated argfiles.

The script is created automatically if there is more than one `javac` call. To
turn off this behavior, use `-N/--no-build-script`.

The build script assumes that it is being called in the same directory as the
argfiles, and so it uses relative paths to access the argfiles.

#### Output directory for argfiles and build script

To specify a directory for the argfiles and the build script, use the option
`-d/--argfiles-dir`.

If there is more than one `javac` call in the file given, then unless the option
`-n/--no-dir` is given, `javac_to_argfile.py` will put the argfiles and the
generated build scirpt in a folder named `all-argfiles`.

### Other notes

All of the paths given by `do-like-javac/dljc` are absolute, so these argfiles
could technically be given to javac anywhere. The same however is not true of
the buildfile, as noted earlier.

## Tips for do-like-javac
The `dljc` executable works fairly well with Maven and Ant, as long as you
have run `ant clean` or `mvn clean` beforehand. However, `dljc` may fail to
find `javac` calls with Gradle for any number of reasons:

- Gradle was being run too often, and so the daemon disappeared prematurely
- The option `--rerun-tasks` wasn't given to Gradle, and so cached build results
  were used instead of actually re-building the targets (this can happen even if
  you run `gradle clean`)
