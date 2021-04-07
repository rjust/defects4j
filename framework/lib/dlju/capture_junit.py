#!/usr/bin/env python

import os
import re
import argparse
import path_utils as putils
import json

def writeCommands(commandsObject, fileName):
    with open(fileName, "w") as f:
        f.write("\n".join(commandsObject))
        f.flush()
def parse_args(outputSuffix=""):
    junit_output_default="junit_commands{}".format(outputSuffix)
    parser = argparse.ArgumentParser()
    parser.add_argument("-l", "--logs",
                       type=str,
                       help="Location of the logs from dljc")
    parser.add_argument("-o", "--output",
                        type=str,
                        default=junit_output_default,
                        help="File to store output commands in. Defaults to \"{}\"".format(junit_output_default))
    return parser.parse_args()

def parse_junit_tasks(output):
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
    paths = cp.split(":")
    paths = [p for p in paths if not re.match(r"ant.*\.jar", os.path.basename(p))]
    return ":".join(paths)
def getJUnitVersion(commandsList):
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
    if version == 4:
        return "org.junit.runner.JUnitCore"
    elif version == 3:
        return "junit.textui.TestRunner"
    return None

def reorderCommands(commandList):
    version = getJUnitVersion(commandList)
    # print(version)
    java_call = commandList.pop(0)
    options = [c for c in commandList if c.startswith("-")]
    classes = [c for c in commandList if not c.startswith("-")]
    testRunner = "org.apache.tools.ant.taskdefs.optional.junit.JUnitTestRunner"
    if testRunner in classes:
        index = classes.index(testRunner)
        if index >= 0:
            classes.pop(index)
            if version == 4:
                classes = ["org.junit.runner.JUnitCore"] + classes
            elif version == 3:
                # Use the JUnit 3 test batch runner
                # info here: http://www.geog.leeds.ac.uk/people/a.turner/src/andyt/java/grids/lib/junit-3.8.1/doc/cookbook/cookbook.htm
                # Does anyone actually use this version of junit?????
                classes = ["junit.textui.TestRunner"] + classes
    return [java_call] + options + classes

def commandify(tasks):
    def combinator(a, b):
        if len(a) == 0:
            return b
        elif a.endswith("classpath") or a.endswith("cp"):
            return "{} {}".format(a, editClasspath(b))
        return "{} {}".format(a, b)
    if len(tasks) > 0:
        all_combined = []
        for task in tasks:
            combined = reorderCommands([combinator(partA, partB) for partA, partB in task])
            all_combined.append(" ".join(combined))
            pass
        return all_combined
    return ""

def getOutput(logsDir):
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
    writeCommands(commandify(junit_tasks), args.output)


if __name__ == '__main__':
    main()
