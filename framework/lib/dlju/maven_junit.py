import capture_junit as cj
tests_begin = """-------------------------------------------------------
 T E S T S
-------------------------------------------------------"""

def findBeginningOfTests(output):
    testLines = tests_begin.split("\n")
    print(testLines)
    for i, o in enumerate(output):
        if o == testLines[0] and (i + 2) < len(output):
            if output[i+1] == testLines[1] and output[i + 2] == testLines[2]:
                return i + 3
    return -1

def findSurefireCommand(output):
    for o in output:
        if o.startswith("Forking command line"):
            return o
    return None

def createCommands(javaCommand, options, lines, ranTests):
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

if __name__ == '__main__':
    args = cj.parse_args(outputSuffix="_maven")
    output = cj.getOutput(args.logs)
    print(len(output))
    output = [o.rstrip() for o in output]
    beginIndex = findBeginningOfTests(output)
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
                    print(command)
                    if command.find("bin/java") >= 0:
                        javaCommand = command
                    elif command.find("-jar") >= 0:
                        i += 1
                    elif command.startswith("-"):
                        # print("Skipping {}".format(command))
                        if isArgumentlessJavaOption(command):
                            options.append(command)
                        else:
                            options.append("{} {}".format(command, commandParts[i + 1]))
                            i += 1
                    elif len(command) > 0:
                        tmpFiles.append(command)
                    i += 1
                print("tmpFiles: {}".format(tmpFiles))
                for tmp in tmpFiles:
                    lines = []
                    with open(tmp, "r") as f:
                        lines = f.readlines()
                    lines = [l.strip() for l in lines]
                    if any(l.startswith("tc") for l in lines):
                        # This is one that we want
                        newCommands = createCommands(javaCommand, options, lines, ran)
                        with open(args.output, "w") as f:
                            f.write("\n".join(newCommands))
                            f.flush()
                        break
