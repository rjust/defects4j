# dljc_to_argfile

Takes the `javac.json` output from [do-like-javac](https://github.com/SRI-CSL/do-like-javac)
and turns it into an argfile that you can give to `javac`.

## Requirements

Requires Python 3, and either Mac OS X or Linux.

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
