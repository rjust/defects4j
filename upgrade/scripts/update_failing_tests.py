import csv
import os

output_file = '../../framework/test/databind.txt'
project_folder = "../../framework/projects/JacksonDatabind"

csv_file = os.path.join(project_folder, "active-bugs.csv")
failing_tests_folder = os.path.join(project_folder, "failing_tests")


with open(output_file) as file:
    lines = file.readlines()

with open(csv_file) as file:
    reader = csv.reader(file)
    rows = [row for row in reader]

# parse file by bug
entries = []
current = []
for line in lines:
    if line.startswith("Checking out") or line.startswith("=="):
        entries.append(current)
        current = []
    current.append(line.strip())
entries.append(current)

results = entries[-2]
entries = entries[1:-2]
rows = rows[1:]
assert len(entries) == len(rows)

# find compilation errors
errors = [[line for line in lines if line.startswith("[javac]") and "error:" in line] for lines in entries]
for i in range(len(errors)):
    lines = errors[i]
    if len(lines) == 0:
        continue

    commit = rows[i][2]
    failing_file = os.path.join(failing_tests_folder, commit)
    with open(failing_file) as file:
        data = file.readlines()

    n = len(lines) // 4
    for j in range(n):
        assert lines[j] == lines[n + j]
        assert lines[j] == lines[(2*n) + j]
        assert lines[j] == lines[(3*n) + j]
    lines = lines[:n]
    
    print(i, end = " ")
    for line in reversed(lines):
        srcidx = line.index("src")
        erroridx = line.index("error")
        path = line[srcidx:erroridx - 2]
        tokens = path.split('/')
        #mapping[tokens[-1]] = 0
        mapping[line] = 0
        print (tokens[-1], end=" ")
    print()




import pdb; pdb.set_trace()


