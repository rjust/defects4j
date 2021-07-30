import capture_junit as cj
import re
import os

tests_begin = """-------------------------------------------------------
 T E S T S
-------------------------------------------------------"""

def findBeginningOfTests(output):
    """ Find where the test running begins

    Parameters
    ----------
    output : list of str
        A list of the build output strings

    Returns
    -------
    int
        The index in the `output` list where the actual tests begin
        If it can't find that index, then it returns -1
    """
    testLines = tests_begin.split("\n")
    # print(testLines)
    for i, o in enumerate(output):
        if o == testLines[0].strip() and (i + 2) < len(output):
            if output[i+1] == testLines[1].strip() and output[i + 2] == testLines[2].strip():
                return i + 3
    return -1

def findSurefireCommand(output):
    """ Find where the maven surefire plugin (which is the test plugin)
        begins its command

    Parameters
    ----------
    output : list of str
        The lines of the build output

    Returns
    -------
    str
        The line that contains the java command to run the maven surefire plugin

    """
    for o in output:
        print(o)
        if o.startswith("Forking command line"):
            return o
    return None

def createCommands(javaCommand, options, lines, ranTests):
    """ Return a list of the junit commands to run

    Parameters
    ----------
    javaCommand : str
        The `java` invocation
    options : list of str
        The command line options for `java`
    lines : list of str
        Lines containing the test classes and classPathUrl
    ranTests : list of str
        A list of the tests that were ran

    Returns
    -------
    list of str
        A list containing commands to run each test class

    """
    print(lines)
    testClasses = [l for l in lines if l.startswith("tc")]
    classPaths = [l for l in lines if l.startswith("classPathUrl")]
    print(len(classPaths))
    testClasses = [l.split("=") for l in testClasses]
    classPaths = [l.split("=") for l in classPaths]
    print(classPaths)
    testClasses = [l[1] for l in testClasses if l[1] in ranTests]
    classPaths = [l[1] for l in classPaths]

    classPath = "-classpath {}".format(":".join(classPaths))
    junitVersion = cj.getJUnitVersion([classPath])
    junitClass = cj.getJunitTestRunnerClass(junitVersion)
    if junitClass is None:
        print("Error: could not find JUnit version for classpath {}".format(classPath))
        exit(1)
    return ["{} {} {} {} {}".format(javaCommand, " ".join(options), classPath, junitClass, tc) for tc in testClasses]
def findRunTests(lines):
    """ From the lines of the build output, figures out which tests were run

    Parameters
    ----------
    lines : list of str
        The lines of the build output file

    Returns
    -------
    list of str
        A list of the names of the tests that were run

    """
    ran = []
    for l in lines:
        if l.startswith("Running"):
            splits = l.split(" ")
            if len(splits) == 2:
                ran.append(splits[1])
        if l.startswith("Results"):
            break
    return ran

def isArgumentlessJavaOption(line):
    """ Determine whether a given line contains a command line option that does
        not take arguments.

    Parameters
    ----------
    line : str
        A line of the build output

    Returns
    -------
    bool
        True if the line contains an option that doesn't take arguments

    """
    argumentlessOptions = ["agentlib",
                           "agentpath",
                           "disableassertions",
                           "D",
                           "da",
                           "enableassertions",
                           "ea",
                           "enablesystemassertions",
                           "esa",
                           "disablesystemassertions",
                           "dsa",
                           "javaagent",
                           "jre-restrict-search",
                           "no-jre-restrict-search",
                           "showversion",
                           "splash",
                           "verbose",
                           "version",
                           "X"]
    for a in argumentlessOptions:
        if line.startswith("-{}".format(a)):
            return True
    return False

def getSurefireDir(tmps):
    for t in tmps:
        if os.path.isdir(t):
            return t
    return None

if __name__ == '__main__':
    args = cj.parse_args(outputSuffix="_maven")
    output = cj.getOutput(args.logs)
    print(len(output))
    output = [o.rstrip() for o in output]
    output = [re.sub(r"\[[^\]]+\]", "", o) for o in output]
    output = [o.strip() for o in output]
    beginIndex = findBeginningOfTests(output)
    print(beginIndex)
    surefire = findSurefireCommand(output[beginIndex:])
    ran = findRunTests(output[beginIndex:])
    if surefire is not None:
        if surefire.find("&&") >= 0:
            splits = surefire.split("&&")
            if len(splits) >= 2:
                secondPart = splits[1]
                commandParts = secondPart.split(" ")
                i = 0
                javaCommand = ""
                options = []
                tmpFiles = []
                print(commandParts)
                while i < len(commandParts):
                    command = commandParts[i]
                    print(f"Command: {command}")
                    if command.find("bin/java") >= 0:
                        javaCommand = command
                    elif command.find("-jar") >= 0:
                        i += 1
                    elif command.startswith("-"):
                        print(f"An option: {command}")
                        # print("Skipping {}".format(command))
                        if isArgumentlessJavaOption(command) or command.find("=") > -1:
                            options.append(command)
                        else:
                            options.append("{} {}".format(command, commandParts[i + 1]))
                            i += 1
                    elif len(command) > 0:
                        tmpFiles.append(command)
                    i += 1
                    pass
                tmpFiles = [tmp for tmp in tmpFiles if tmp.find("surefire") > -1]

                print("tmpFiles: {}".format(tmpFiles))
                surefireDir = getSurefireDir(tmpFiles)
                tmpFiles = [t for t in tmpFiles if t != surefireDir]
                for tmp in tmpFiles:
                    lines = []
                    with open(os.path.join(surefireDir, tmp), "r") as f:
                        lines = f.readlines()
                    lines = [l.strip() for l in lines]
                    if any(l.startswith("tc") for l in lines):
                        # This is one that we want
                        newCommands = createCommands(javaCommand, options, lines, ran)
                        with open(args.output, "w") as f:
                            f.write("\n".join(newCommands))
                            f.flush()
                        break
                    pass
                pass
            pass
        pass
    else:
        print("Surefire is none")
