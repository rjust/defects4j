#!/usr/bin/env python
""" Parse junit output from the do-like-javac build output, and create a file
    containing all of the commands to run tests
    (Outputted commands did not work last time I checked, but this script can be
    used to extract classpaths, test classes, etc.)
"""


import os
import re
import argparse
import path_utils as putils
import json

def writeCommands(commandsObject, fileName):
    """ Outputs the junit commands to a file

    Parameters
    ----------
    commandsObject : list of str
        Description of parameter `commandsObject`.
    fileName : str
        The file to write the commands to

    """
    with open(fileName, "w") as f:
        f.write("\n".join(commandsObject))
        f.flush()
def parse_args(outputSuffix=""):
    """ Set up and parse command line arguments

    Parameters
    ----------
    outputSuffix : str
        Optional suffix to append to the output. Defaults to "".

    Returns
    -------
    object containing args
        The result of calling argparse.ArgumentParser.parse_args

    """
    junit_output_default="junit_commands{}".format(outputSuffix)
    parser = argparse.ArgumentParser()
    parser.add_argument("-l", "--logs",
                       type=str,
                       help="Location of the logs from dljc")
    parser.add_argument("-o", "--output",
                        type=str,
                        default=junit_output_default,
                        help="File to store output commands in. Defaults to \"{}\"".format(junit_output_default))
    parser.add_argument("-i", "--info-only",
                        action="store_true",
                        help="Only produce information, and don't create commands. Will produce the classpath and the test classes instead.")
    return parser.parse_args()

def parse_junit_tasks(output):
    """ Parse junit tasks from the build output

    Parameters
    ----------
    output : list of str
        A list of the strings in the build output file from dljc

    Returns
    -------
    list of junit tasks
        A list containing the junit tasks

    """
    i = 0
    output = [o.strip() for o in output]
    def getQuotedString(mystr):
        if re.search(r"\'[^\']+\'", mystr):
            return re.sub(r"[^\']+\'([^\']+)\'.*", r"\1", mystr)
        return None
    def isOption(mystr):
        return mystr.startswith("-")
    def add_junit_task(beginIndex):
        print("Beginning")
        index = beginIndex
        obj = []
        lastWasOption = False
        lastOption = ""
        while output[index].startswith("[junit]") and output[index].find("The \' characters around the executable and arguments") == -1:
            unquoted = getQuotedString(output[index])
            if unquoted is not None:
                if isOption(unquoted):
                    lastOption = unquoted
                    lastWasOption = True
                    pass
                elif lastWasOption:
                    obj.append((lastOption, unquoted))
                    lastWasOption = False
                    pass
                else:
                    if unquoted.find("=") > 0 and unquoted.find("=") < len(unquoted) - 1:
                        # Add system property
                        obj.append(("", "-D{}".format(unquoted)))
                        pass
                    else:
                        obj.append(("", unquoted))
                        pass
                    pass
                pass
            index += 1
            pass
        return (obj, index)
    tasks = []
    print("len: {}".format(len(output)))
    while i < len(output):
        line = output[i].strip()
        stupid_bool = True if line.startswith("[junit]") and re.match(r"\[junit\]\s*Executing\s*\'[-a-zA-Z0-9./@_ ]+\' with arguments:", line) else False
        #if line.startswith("[junit]") and re.match(r"\[junit\]\s*Executing\s*\'[a-zA-Z0-9./ ]+\' with arguments:", line):
        if stupid_bool:
            print("Hello???")
            oldi = i
            task, i = add_junit_task(i)
            print("i, oldi: {} {}".format(i, oldi))
            tasks.append(task)
        else:
            i += 1
    print(tasks)
    return tasks

def editClasspath(cp):
    """ Remove ant jars from the classpath

    Parameters
    ----------
    cp : str
        The classpath for junit

    Returns
    -------
    str
        A classpath string for running tests

    """
    paths = cp.split(":")
    paths = [p for p in paths if not re.match(r"ant.*\.jar", os.path.basename(p))]
    return ":".join(paths)
def getJUnitVersion(commandsList):
    """ Find the junit version

    Parameters
    ----------
    commandsList : list of str
        A list of the parts of a command for running junit

    Returns
    -------
    None, int, or str
        Returns None if it cannot find the string junit in the classpath string
        Returns -1 if it cannot find a string of the format `junit-\d+\.\d+`
        Returns a str of the major junit verison

    """
    if any(c.startswith("-classpath") or c.startswith("-cp") for c in commandsList):
        classpaths = [c for c in commandsList if c.startswith("-classpath") or c.startswith("-cp")]
        if len(classpaths) == 1:
            splits = classpaths[0].split(" ")
            if len(splits) == 2:
                cp = splits[1].split(":")
                if any(p.find("junit") >= 0 for p in cp):
                    junitPaths = [p for p in cp if p.find("junit") >= 0]
                    match = [re.search(r"junit-(\d+\.\d+)", p) for p in junitPaths]
                    match = [m for m in match if m]
                    match = [int(re.sub(r"(\d+).\d+", r"\1", m.group(1))) for m in match]
                    matchset = set(match)
                    if len(matchset) == 1:
                        return list(match)[0]
                    return -1

def getJunitTestRunnerClass(version):
    """ Get the correct junit test running class for the given junit version

    Parameters
    ----------
    version : int
        The major version for junit

    Returns
    -------
    str or None
        Returns str if `version` is either 3 or 4
        Returns None otherwise

    """
    if version == 4:
        return "org.junit.runner.JUnitCore"
    elif version == 3:
        # Use the JUnit 3 test batch runner
        # info here: http://www.geog.leeds.ac.uk/people/a.turner/src/andyt/java/grids/lib/junit-3.8.1/doc/cookbook/cookbook.htm
        # Does anyone actually use this version of junit?????
        return "junit.textui.TestRunner"
    return None

def reorderCommands(commandList):
    """ Reorder the parts of the junit command so that it is in the order of

        1. `java` call
        2. `java` runtime options
        3. `java` classes to run

    Parameters
    ----------
    commandList : list of str
        A list of the parts of the junit command

    Returns
    -------
    list of str
        A list of the parts of the junit command, in the given order

    """
    version = getJUnitVersion(commandList)
    # print(version)
    java_call = commandList.pop(0)
    options = [c for c in commandList if c.startswith("-")]
    classes = [c for c in commandList if not c.startswith("-")]
    # Remove the ant junit test runner and replace with a normal junit test runner
    testRunner = "org.apache.tools.ant.taskdefs.optional.junit.JUnitTestRunner"
    if testRunner in classes:
        index = classes.index(testRunner)
        if index >= 0:
            classes.pop(index)
            junitClass = getJunitTestRunnerClass(version)
            if junitClass:
                # Only add it if it is not None
                classes = [junitClass] + classes
    return [java_call] + options + classes

def commandify(tasks, partsOnly=False):
    """ Turn the junit tasks, which are stored as parts, into single command
        strings.

    Parameters
    ----------
    tasks : list of list of tuples of strings
        tasks level: [
            task level: [
                option level: (_ , _) # The former part of the tuple is empty if
                                      # this isn't a switch
            ]
        ]

    Returns
    -------
    list of str
        A list of junit command strings

    """
    def combinator(a, b):
        if len(a) == 0:
            return b
        elif a.endswith("classpath") or a.endswith("cp"):
            return "{} {}".format(a, editClasspath(b))
        return "{} {}".format(a, b)
    if len(tasks) > 0:
        all_combined = []
        if partsOnly:
            for task in tasks:
                simplified = [combinator(partA, partB) for partA, partB in task]
                if len(simplified > 1):
                    simplified.pop(0)
                    classpaths = [c for c in simplified if c.startswith("-classpath") or c.startswith("-cp")]
                    classes = [c for c in simplified if not c.startrswith("-")]
                    all_combined.append((classpaths, classes))
                    pass
                pass
            pass
        else:
            for task in tasks:
                combined = reorderCommands([combinator(partA, partB) for partA, partB in task])
                all_combined.append(" ".join(combined))
                pass
            pass
        return all_combined
    return ""

def getOutput(logsDir):
    """ Find the build output in the dljc logs directory

    Parameters
    ----------
    logsDir : str
        Path to the dljc logs directory

    Returns
    -------
    list of str
        The lines of the dljc build output file

    """
    if not os.path.exists(os.path.join(logsDir, "build_output.txt")):
        print("Warning: the directory {} does not exist!".format(args.logs))
        exit(1)
        pass

    output = []
    with open(os.path.join(logsDir, "build_output.txt"), "r") as f:
        output = f.readlines()
        pass
    return output

def main():
    args = parse_args()

    output = getOutput(args.logs)
    # print(output)
    junit_tasks = parse_junit_tasks(output)
    commands = commandify(junit_tasks, partsOnly=args.info_only)
    if args.info_only:
        print(commands)
        pass
    else:
        writeCommands(commandify(junit_tasks, partsOnly=args.info_only), args.output)


if __name__ == '__main__':
    main()
