""" Take the output from do-like-javac (dljc) and turn this into an argfile for
    javac.
"""

import json
import argparse
import os
import path_utils as putils
import re
import readline
import os_utils as otils

def setup_args():
    """ Setup commandline arguments

    Returns
    -------
    object containing args
        The result of calling `argparse.ArgumentParser.parse_args`

    """
    parser = argparse.ArgumentParser(description="Turns the json javac output from do-like-javac into a javac argfile")

    parser.add_argument("file", type=str,
                        help="The location of the json do-like-javac output to turn into an argfile")
    parser.add_argument("-o", "--options",
                        type=str,
                        default="options",
                        help="Name/location of the options file. Defaults to \"options\"")
    parser.add_argument("-c", "--classes",
                        type=str,
                        default="classes",
                        help="Name/location of the classes file to be output. Defaults to \"classes\"")
    parser.add_argument("-d", "--argfiles-dir",
                        type=str,
                        default=None,
                        help="The directory to put all generated argfiles. By default, if there is only one javac call in the json file, it puts the argfiles into the current directory. However, if there are multiple javac calls, it will default to putting them into a directory called all-argfiles, which will be in the current directory, unless you turn on the flag --no-dirs.")
    parser.add_argument("-n", "--no-dir",
                        action='store_true',
                        help="If this option is provided and no --argfiles-dir is specified, then it will always output all argfiles into the current directory, even if there are multiple javac calls. Note that if --argfiles-dir/-d is given, then this option is ignored.")
    parser.add_argument("-b", "--build-script",
                        type=str,
                        default=None,
                        help="If provided, this will automagically generate a shell script to run that will execute all of the javac commands found in the provided javac.json file. Even if the option isn't provided, if there is more than one javac call in the javac json file, it will by default call it build_all.sh, and it will be placed either in the argfiles directory (with no -n/--no-dir specified) or in the current directory (with -n/--no-dir specified). To turn off this default behavior, use the option -N/--no-build-script.")
    parser.add_argument("-N", "--no-build-script",
                        action='store_true',
                        help="If -N/--no-build-script is given and -b/--build-script is not specified, then javac_to_argfile.py will not attempt to automagically generated a shell script that runs all of the javac commands. If -b/--build-script is specified, then this option is ignored.")
    parser.add_argument("--bootclasspath",
                        type=str,
                        nargs=2,
                        default=None,
                        help="Give the java version (1.7, 1.8, etc.) and bootclasspath to use for that version.")
    parser.add_argument("--always-ask",
                        action='store_true',
                        help="Turns on always asking which bootclasspath to use, whenever -Werrror and -source or -target is specified, since if you compile using a javac for a higher java version than either -source or -target, then you will get a warning that makes compilation fail. By  default, it just uses the previously used bootclasspath for the given java version.")
    args = parser.parse_args()
    return args


def wrap_paths_with_spaces_with_quote_marks(possiblePath):
    """ Helper function to find spaces in paths, and if so, wraps the path in
        quotation marks.

    Parameters
    ----------
    possiblePath : str
        A string that may be a path

    Returns
    -------
    str
        A path that has been properly wrapped in quotation marks, if needed

    """
    # TODO: This seems to actually do the _opposite_ of what the name suggests
    if putils.path_exists_or_is_creatable(possiblePath):
        if possiblePath.find(" ") == -1:
            return "\"{}\"".format(possiblePath)
    return possiblePath

def configure_target_or_source(switch, key):
    """ Obtains the java version to be used for the target or source switch, if
        the given `switch` is either `target` or `source`.

    Parameters
    ----------
    switch : str
        A javac switch, without the preceding `-`
    key : str or bool
        The value given to the switch, if any

    Returns
    -------
    str or bool
        If the switch is either target or source, and the key is not a boolean,
        then a string containing the java version without the preceding `1.`
        Else, returns the key, unaltered.

    """
    if switch in ["source", "target"]:
        if not isinstance(key, bool) and key.startswith("1."):
            return key[2:]
    return key

def mayNeedBootClassPath(switches):
    """ Indicates that to make the build work, we will need to suppress
        potential `bootclasspath not found` warnings that have been promoted to
        errors.

    Parameters
    ----------
    switches : list of str
        A list of all of the javac switches found in the dljc output

    Returns
    -------
    bool
        True if the bootclasspath should be specified.

    """
    return "Werror" in switches and ("source" in switches or "target" in switches)

def getPath(version):
    """ Ask the user to provide a path for the bootclasspath

    Parameters
    ----------
    version : str
        A string describing the Java version

    Returns
    -------
    str
        The path, if specified, otherwise an empty string

    """
    jarname = "rt"
    if otils.isMacOsX() and version in ["1.1", "1.2", "1.3", "1.5", "5", "1.6", "6"]:
        print("Please specify the location of the Java {} classes.jar file (usually rt.jar on Mac OS X for Java versions >= 7)".format(version))
        jarname = "classes"
    else:
        print("Please specify the location of the Java {} rt.jar file".format(version))
        pass
    path = input("{}.jar location: ".format(jarname))
    while path != "" and not os.path.exists(path):
        print("Sorry, the path {} does not exist.".format(path))
        path = input("{}.jar location (or hit enter to cancel setting the bootclasspath): ".format(jarname))
        pass
    return path

def addBootClassPath(switches,
                     switches_key,
                     call,
                     java_bootclasspath_version_locations,
                     always_ask):
    """ Add the boot class path, if needed

    Parameters
    ----------
    switches : list of str
        The list of the javac switches to examine
    switches_key : str
        The key for the switches in the call
    call : dict
        A dictionary (obtained from JSON) describing the javac call
    java_bootclasspath_version_locations : dict
        A dictionary for containing the java rt.jar or classes.jar locations,
        where the keys are the java version. This is altered by this function
        (by reference)
    always_ask : bool
        Whether to always ask for the boot classpath from the user.

    """
    src = call[switches_key]["source"] if "source" in call[switches_key] else ""
    trgt = call[switches_key]["target"] if "target" in call[switches_key] else ""
    these_options_names = [switch for switch in call[switches_key] if switch == "source" or switch == "target"]
    these_options_names = sorted(these_options_names)
    these_options = [src, trgt] if len(src) > 0 and len(trgt) > 0 else ([src] if len(trgt) == 0 else [trgt])
    print("-Werror specified, in addition to {}".format(
        "{}: {}".format(
            ",".join(list(map(lambda x: "-{}".format(x), these_options_names))),
            ",".join(these_options))))
    print("Warning: if the bootclasspath is not set correctly for the source/target Java version, you will get a warning that will make your compilation fail, due to -Werror being set.")
    boot_paths = []
    def add_path_to_bootclasspath(path):
        if path != "" and len(boot_paths) > 0:
            print("Setting -bootclasspath to {}".format(":".join(boot_paths)))
            switches.append("-bootclasspath {}".format(":".join(boot_paths)))
        elif len(boot_paths) == 0:
            print("No boot paths to add.")
            pass
    unique_java_versions = list(set([version for version in these_options if version not in java_bootclasspath_version_locations]))
    if any(version not in java_bootclasspath_version_locations for version in these_options):
        want_to_specify_bootclasspath = input("Would you like to to specify the bootclasspath? (y/n)")
        if want_to_specify_bootclasspath.lower() == "y":
            if otils.isMacOsX():
                print("Detected operating system: Mac OS X")
                pass
            if otils.isLinux():
                print("Detected operating system: Linux")
                pass

            for v in unique_java_versions:
                path = getPath(v)
                if path == "":
                    print("Cancelling setting the classpath....")
                    break
                else:
                    java_bootclasspath_version_locations[v] = path
                    boot_paths.append(path)
            add_path_to_bootclasspath(path)
            pass
        else:
            print("Skipping setting the bootclasspath")
            pass
        pass
    else:
        # In this instance, you've already previously specified what the boot
        # classpath should be for the particular versions of java asked for
        unique_java_versions = list(set(these_options))
        if not always_ask:
            path = ""
            for version in unique_java_versions:
                print("Using old bootclasspath {} for Java {} by default...".format(java_bootclasspath_version_locations[version], version))
                path = java_bootclasspath_version_locations[version]
                boot_paths.append(path)
                pass
            add_path_to_bootclasspath(path)
            pass
        else:
            want_to_use_bootclasspath = input("Would you like to set the -bootclasspath option for this javac call? (y/n): ")
            if want_to_use_bootclasspath.lower() == "y":
                want_to_use_previous_bootclasspaths = input("Would you like to just use the previously given paths for Java version{} {}? (y/n): ".format("" if len(unique_java_versions) == 1 else "s", ", ".join(unique_java_versions)))
                if want_to_use_previous_bootclasspaths.lower() == "y":
                    print("Okay, using previous settings:")
                    for version in unique_java_versions:
                        print("Using path {} for Java {}".format(java_bootclasspath_version_locations[version], version))
                        pass
                    pass
                else:
                    path = ""
                    for version in unique_java_versions:
                        use_new = input("Would you like to specify a new rt.jar for Java {}? (y/n): ".format(version))
                        if use_new.lower() == "y":
                            path = getPath(version)
                            if path == "":
                                print("Cancelling setting the bootclasspath")
                                break
                            else:
                                boot_paths.append(path)
                                pass
                            pass
                        if use_new.lower() == "n":
                            print("Using old bootclasspath {} for Java {} by default...".format(java_bootclasspath_version_locations[version], version))
                            boot_paths.append(java_bootclasspath_version_locations[version])
                            pass
                        pass
                    add_path_to_bootclasspath(path)
                    pass
                pass
            else:
                print("Skipping setting the -bootclasspath option...")
                pass
            pass
        pass
    pass


def checkFileName(fileName):
    """ Check that the file name given is JSON and exists -- this file should
        be the javac file created by dljc

    Parameters
    ----------
    fileName : str
        The name of the file containing the javac call

    """
    if not os.path.exists(fileName):
        print("Warning: file named {} does not exist. Please check to make sure you spelled it correctly and have the right file.".format(fileName))
        print("Exiting now.")
        exit(1)
        pass
    elif not fileName.endswith(".json"):
        print("Warning: file {} does not have a json file extension.".format(fileName))
        pass
    pass

def main():
    # Setup commandline parsing with tab completion
    readline.set_completer_delims(' \t\n=')
    readline.parse_and_bind("tab:complete")
    args = setup_args()
    fileName = args.file
    print(args.file)

    argsfileDir = ""

    if args.argfiles_dir is not None:
        argsfileDir = args.argfiles_dir

        if not os.path.exists(argsfileDir):
            os.makedirs(argsfileDir)
            pass
        pass



    checkFileName(fileName)


    javac_calls = []
    try:
        with open(fileName, "r") as f:
            javac_calls = json.loads(f.read())
            pass
        pass
    except Exception as e:
        print("Please make sure that the json file that you provided has content in it.")
        print(e)
        pass

    buildScript = ""

    if args.build_script is not None:
        buildScript = args.build_script
        if len(buildScript) == 0:
            print("Expected a build script name, but got an empty string. Please provide the name/location of a build script, such as using -b some/path/my_script.sh or --build-script other/path/my_build_script.sh")
            exit(1)
            pass
        else:
            dirs, name = os.path.split(buildScript)
            if len(dirs) > 0 and not os.path.exists(dirs):
                os.makedirs(dirs)
                pass
            pass
        pass


    if len(javac_calls) > 1:
        if args.argfiles_dir is None and not args.no_dir:
            argsfileDir = "all-argfiles"
            if not os.path.exists(argsfileDir):
                os.mkdir(argsfileDir)
                pass
            pass
        if args.build_script is None and not args.no_build_script:
            buildScript = "build_all.sh"
            pass
        pass

    # print(len(javac_calls))
    buildfile_lines = []
    java_bootclasspath_version_locations = {}
    i = 0
    for call in javac_calls:
        # We create an argfile per call
        i += 1
        # This provides a suffix for the created argfiles
        s = str(i)
        if len(javac_calls) == 1:
            s = ""
            pass

        classes_file = "{}{}".format(args.classes, s)
        classes_file = os.path.join(argsfileDir, classes_file) if len(argsfileDir) > 0 else classes_file
        options_file = "{}{}".format(args.options, s)
        options_file = os.path.join(argsfileDir, options_file) if len(argsfileDir) > 0 else options_file
        files_key = "java_files"
        switches_key = "javac_switches"
        if files_key in call and switches_key in call:
            files = [wrap_paths_with_spaces_with_quote_marks(f) for f in call[files_key]]
            switches = [(switch, arg)
                        for switch, arg in call[switches_key].items()
                        if not (switch == "sourcepath" and isinstance(arg, str) and len(arg) == 0)]
            switches = ["{} {}".format("-{}".format(switch)
                                       if not isinstance(arg, bool) or arg
                                       else "",
                                       wrap_paths_with_spaces_with_quote_marks(arg)
                                       if not isinstance(arg, bool) and not re.match(r"source|target", switch)
                                       else (configure_target_or_source(switch, arg)
                                             if re.match(r"source|target", switch)
                                             else ""))
                        for switch, arg in switches]
            if mayNeedBootClassPath(call[switches_key]) and "bootclasspath" not in call[switches_key]:
                addBootClassPath(switches, switches_key, call, java_bootclasspath_version_locations, args.always_ask)
            print("Outputting classes into {} and options in {}".format(classes_file, options_file))
            with open(classes_file, "w") as f:
                if len(call[files_key]) >= 1:
                    f.write("\n".join(files))
                    pass
                else:
                    f.write("")
                    pass
                pass
            with open(options_file, "w") as f:
                if len(call[switches_key].keys()) >= 1:
                    f.write("\n".join(switches))
                    pass
                else:
                    f.write("")
                pass
            if len(buildScript) > 0: # We're actually going to output a build script
                # Directories given in switches -d, -s MUST exist -- javac will not create them
                if "d" in call[switches_key] and len(call[switches_key]["d"]) > 0:
                    d_val = wrap_paths_with_spaces_with_quote_marks(call[switches_key]["d"])
                    # d_val = d_val if d_val.find(" ") == -1 else "\"{}\"".format(d_val)
                    buildfile_lines.append("# Since -d {} given and the -d DIR option requires DIR to already exist,".format(d_val))
                    buildfile_lines.append("# have to try to create this directory.")
                    buildfile_lines.append("mkdir -p {}".format(d_val))
                    pass
                if "s" in call[switches_key] and len(call[switches_key]["s"]) > 0:
                    s_val = wrap_paths_with_spaces_with_quote_marks(call[switches_key]["s"])
                    # s_val = s_val if s_val.find(" ") == -1 else "\"{}\"".format(s_val)
                    buildfile_lines.append("mkdir -p {}".format(s_val))
                    pass
                classes_loc = os.path.basename(classes_file) if not args.no_dir else classes_file
                options_loc = os.path.basename(options_file) if not args.no_dir else options_file
                buildfile_lines.append("javac @{} @{}".format(classes_loc, options_loc))
                buildfile_lines.append("echo \"Done with javac @{} @{}\"".format(classes_loc, options_loc))
                pass
            pass
        pass
    if len(buildfile_lines) > 0:
        with open(os.path.join(argsfileDir, buildScript), "w") as f:
            #if not buildScript.endswith(".sh"):
            f.write("#!/usr/bin/env bash\n\n")
            f.write("# Must call this script from the same directory as the classes and options argfiles\n")
            f.write("\n".join(buildfile_lines))
            f.flush()
            pass
        pass
    pass




if __name__ == '__main__':
    main()
    pass
