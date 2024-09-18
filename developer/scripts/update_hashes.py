from git import Repo
import csv
import os

# paths
old_repo_path = "../../project_repos/commons-math.git"
new_repo_path = "../../../commons-math"
project_folder = "../../framework/projects/Math"

#old_repo_path = "../../project_repos/commons-lang.git"
#new_repo_path = "../../../commons-lang"
#project_folder = "../../framework/projects/Lang"

layout_path = os.path.join(project_folder, "dir-layout.csv")
db_path = os.path.join(project_folder, "commit-db")
active_path = os.path.join(project_folder, "active-bugs.csv")
deprecated_path = os.path.join(project_folder, "deprecated-bugs.csv")
failing_folder = os.path.join(project_folder, "failing_tests")
build_folder = os.path.join(project_folder, "build_files")

# get rows
with open(layout_path) as layout:
    layout_reader = csv.reader(layout)
    layout_rows = [row for row in layout_reader]

# aggregate hashes
old_hashes = set(row[0] for row in layout_rows)

# match on messages
old_repo = Repo(old_repo_path)
messages = {commit.message: commit.hexsha for commit in old_repo.iter_commits() if commit.hexsha in old_hashes}

new_repo = Repo(new_repo_path)
mapping = {}
for commit in new_repo.iter_commits():
    if commit.message in messages:
        old_hash = messages[commit.message]
        assert old_hash not in mapping
        mapping[old_hash] = commit.hexsha

# match remaining on datetime, print messages for inspection
remaining = [sha for sha in old_hashes if sha not in mapping]
if len(remaining) > 0:
    timestamps = {commit.committed_datetime: commit.hexsha for commit in old_repo.iter_commits() if commit.hexsha in remaining}
    for commit in new_repo.iter_commits():
        if commit.committed_datetime in timestamps:
            old_hash = timestamps[commit.committed_datetime]
            assert old_hash not in mapping
            old_message = [message for message, sha in messages.items() if sha == old_hash]
            assert len(old_message) == 1
            old_message = old_message[0]
            print(old_message)
            print("-----------")
            print(commit.message)
            print("=============")
            mapping[old_hash] = commit.hexsha

assert len(mapping) == len(old_hashes)

# modify csv rows and write results
for layout_row in layout_rows:
    layout_row[0] = mapping[layout_row[0]]

with open(layout_path, "w") as layout:
    layout_writer = csv.writer(layout)
    for row in layout_rows:
        layout_writer.writerow(row)

with open(db_path) as commitdb:
    commit_reader = csv.reader(commitdb)
    db_rows = [row for row in commit_reader]

for db_row in db_rows:
    db_row[1] = mapping[db_row[1]]
    db_row[2] = mapping[db_row[2]]

with open(db_path, "w") as commitdb:
    commit_writer = csv.writer(commitdb)
    for row in db_rows:
        commit_writer.writerow(row)

with open(active_path) as active:
    active_reader = csv.reader(active)
    active_rows = [row for row in active_reader]
 
for active_row in active_rows[1:]:
    active_row[1] = mapping[active_row[1]]
    active_row[2] = mapping[active_row[2]]

with open(active_path, "w") as active:
    commit_writer = csv.writer(active)
    for row in active_rows:
        commit_writer.writerow(row)

with open(deprecated_path) as deprecated:
    deprecated_reader = csv.reader(deprecated)
    deprecated_rows = [row for row in deprecated_reader]

for deprecated_row in deprecated_rows[1:]:
    deprecated_row[1] = mapping[deprecated_row[1]]
    deprecated_row[2] = mapping[deprecated_row[2]]

with open(deprecated_path, "w") as deprecated:
    commit_writer = csv.writer(deprecated)
    for row in deprecated_rows:
        commit_writer.writerow(row)

# fix failing_test files
for name in os.listdir(failing_folder):
    fullname = os.path.join(failing_folder, name)
    new_hash = mapping[name]
    with open(fullname) as file:
        data = file.read()
    data = data.replace(name, new_hash)
    with open(fullname, "w") as file:
        file.write(data)
    new_path = os.path.join(failing_folder, new_hash)
    os.rename(fullname, new_path)

# fix build directories
for name in os.listdir(build_folder):
    fullname = os.path.join(build_folder, name)
    new_hash = mapping[name]
    new_path = os.path.join(build_folder, new_hash)
    os.rename(fullname, new_path)
