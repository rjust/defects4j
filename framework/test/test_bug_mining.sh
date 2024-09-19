#!/usr/bin/env bash
################################################################################
#
# This script tests the bug-mining framework.
#
################################################################################

set -e

HERE="$(cd "$(dirname "$0")" && pwd)" || { echo "cannot cd to $(dirname "$0")"; exit 2; }

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

BUG_MINING_FRAMEWORK_DIR="$BASE_DIR/framework/bug-mining"
[ -d "$BUG_MINING_FRAMEWORK_DIR" ] || die "$BUG_MINING_FRAMEWORK_DIR does not exist"

RESOURCES_OUTPUT_DIR="$HERE/resources/output/bug-mining"

main() {
    # Stop at the very first error (there is no point in running later stages of the
    # bug-mining pipeline if earlier stages failed and preconditions are violated.)
    HALT_ON_ERROR=1
    
    # Bug-mining temporary directory
    WORK_DIR="$TMP_DIR/test_bug_mining"
    rm -rf "$WORK_DIR"
    
    # Project example
    PROJECT_ID="TestCodec"
    PROJECT_NAME="commons-test-codec"
    REPOSITORY_URL="https://github.com/apache/commons-codec.git"
    ISSUE_TRACKER_NAME="jira"
    ISSUE_TRACKER_PROJECT_ID="CODEC"
    BUG_FIX_REGEX="/(CODEC-\d+)/mi"
    
    test_create_project "$PROJECT_ID" "$PROJECT_NAME" "$WORK_DIR" "$REPOSITORY_URL" || die "Test 'test_create_project' has failed!"
    test_download_issues "$WORK_DIR" "$ISSUE_TRACKER_NAME" "$ISSUE_TRACKER_PROJECT_ID" || die "Test 'test_download_issues' has failed!"
    test_crossref_commmit_issue "$PROJECT_ID" "$PROJECT_NAME" "$WORK_DIR" "$BUG_FIX_REGEX" || die "Test 'test_crossref_commmit_issue' has failed!"
    
    ISSUE_ID="CODEC-231"
    grep -q ",$ISSUE_ID," "$WORK_DIR/framework/projects/$PROJECT_ID/$BUGS_CSV_ACTIVE" || die "$ISSUE_ID has not been mined"
    BUG_ID=$(grep ",$ISSUE_ID," "$WORK_DIR/framework/projects/$PROJECT_ID/$BUGS_CSV_ACTIVE" | cut -f1 -d',')
    
    test_initialize_revisions "$PROJECT_ID" "$WORK_DIR" "$BUG_ID" || die "Test 'test_initialize_revisions' has failed!"
    test_analyze_project "$PROJECT_ID" "$WORK_DIR" "$ISSUE_TRACKER_NAME" "$ISSUE_TRACKER_PROJECT_ID" "$BUG_ID" || die "Test 'test_analyze_project' has failed!"
    test_get_trigger "$PROJECT_ID" "$WORK_DIR" "$BUG_ID" || die "Test 'test_get_trigger' has failed!"
    test_get_metadata "$PROJECT_ID" "$WORK_DIR" "$BUG_ID" || die "Test 'test_get_metadata' has failed!"
    test_promote_to_db "$PROJECT_ID" "$PROJECT_NAME" "$WORK_DIR" "$BUG_ID" || die "Test 'test_promote_to_db' has failed!"
    
    ## Clean up temporary directory
    rm -rf "$WORK_DIR"
    
    test_integration "$PROJECT_ID" "1" || die "Test 'test_integration' has failed!"
    
    # Clean up D4J
    rm -rf "$HERE/../projects/$PROJECT_ID" "$HERE/../core/Project/$PROJECT_ID.pm" "$REPOS_DIR/$PROJECT_NAME.git"
    
    # Print a summary of what went wrong
    if [ "$ERROR" -ne "0" ]; then
        printf '=%.s' $(seq 1 80) 1>&2
        echo 1>&2
        echo "The following errors occurred:" 1>&2
        cat "$LOG" 1>&2
    fi
    
    # Indicate whether an error occurred
    exit "$ERROR"
}

_check_output() {
    [ $# -eq 2 ] || die "Usage: ${FUNCNAME[0]} <actual> <expected>"

    local actual="$1"
    local expected="$2"

    [ ! -s "$actual" ] && [ ! -s "$expected" ] && return

    [ -s "$actual" ] || die "$actual does not exist or it is empty"
    [ -s "$expected" ] || die "$expected does not exist or it is empty"

    sort "$actual" > "$actual.sorted"
    sort "$expected" > "$expected.sorted"

    if ! cmp --silent "$expected.sorted" "$actual.sorted" ; then
        rm -f "$actual.sorted" "$expected.sorted"
        die "'$actual' is not equal to '$expected'!"
    fi

    rm -f "$actual.sorted" "$expected.sorted"
}

# MacOS does not install the timeout command by default.
if [ "$(uname)" = "Darwin" ] ; then
  function timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }
fi

# Download the remote resource to a local file of the same name, if the
# remote resource is newer.  Works around connections that hang.  Takes a
# single command-line argument, a URL.
download_url() {
    BASENAME=$(basename "${@: -1}")
    if [ "$(uname)" = "Darwin" ] ; then
        wget -nv -N "$@"
    else
	timeout 300 curl -s -S -R -L -O -z "$BASENAME" "$@" || (echo "retrying curl $*" && rm -f "$BASENAME" && curl -R -L -O -z "$BASENAME" "$@")
    fi
}

#
# Exercises the create-project.pl script.
#
test_create_project() {
    [ $# -eq 4 ] || die "Usage: ${FUNCNAME[0]} <project_id> <project_name> <work_dir> <repository_url>"

    local project_id="$1"
    local project_name="$2"
    local work_dir="$3"
    local repository_url="$4"

    pushd . > /dev/null 2>&1
    cd "$BUG_MINING_FRAMEWORK_DIR"
    ./create-project.pl -p "$project_id" -n "$project_name" -w "$work_dir" -r "$repository_url" || die "Create project script has failed"
    popd > /dev/null 2>&1

    # Check whether expected directories exist
    [ -d "$work_dir/framework/projects/$project_id/trigger_tests" ] || die "trigger_tests directory does not exist"
    [ -d "$work_dir/framework/projects/$project_id/modified_classes" ] || die "modified_classes directory does not exist"
    [ -d "$work_dir/framework/projects/$project_id/patches" ] || die "patches directory does not exist"
    [ -d "$work_dir/framework/projects/$project_id/relevant_tests" ] || die "relevant_tests directory does not exist"
    [ -d "$work_dir/framework/projects/$project_id/failing_tests" ] || die "failing_tests directory does not exist"
    [ -d "$work_dir/framework/projects/$project_id/loaded_classes" ] || die "loaded_classes directory does not exist"
    [ -d "$work_dir/issues" ] || die "issues directory does not exist"
    [ -d "$work_dir/project_repos/$project_name.git" ] || die "$work_dir/project_repos/$project_name.git directory does not exist"

    # Check whether expected files exist
    local project_perl_module="framework/core/Project/$project_id.pm"
    local project_build_patch="framework/projects/$project_id/build.xml.patch"
    local project_build_xml="framework/projects/$project_id/$project_id.build.xml"

    [ -s "$work_dir/$project_perl_module" ] || die "Project Perl module does not exist or it is empty"
    [ -s "$work_dir/$project_build_patch" ] || die "build.xml.patch does not exist or it is empty"
    [ -s "$work_dir/$project_build_xml" ] || die "Project build file does not exist or it is empty"
    [ -f "$work_dir/framework/projects/$project_id/$BUGS_CSV_ACTIVE" ] || die "active-bugs csv does not exist"
    [ -f "$work_dir/framework/projects/$project_id/$BUGS_CSV_DEPRECATED" ] || die "deprecated-bugs csv does not exist"
    [ -s "$work_dir/project_repos/README" ] || die "README file in $work_dir/project_repos does not exist or it is empty"

    # Check whether content of expected files is correct
    _check_output "$work_dir/$project_perl_module" "$RESOURCES_OUTPUT_DIR/$project_perl_module"

}

#
# Exercises the download-issues.pl script.
#
test_download_issues() {
    [ $# -eq 3 ] || die "Usage: ${FUNCNAME[0]} <work_dir> <issue_tracker_name> <issue_tracker_project_id>"

    local work_dir="$1"
    local issue_tracker_name="$2"
    local issue_tracker_project_id="$3"

    local issues_dir="$work_dir/issues"
    local issues_file="$work_dir/issues.txt"

    pushd . > /dev/null 2>&1
    cd "$BUG_MINING_FRAMEWORK_DIR"
    ./download-issues.pl -g "$issue_tracker_name" -t "$issue_tracker_project_id" -o "$issues_dir" -f "$issues_file" || die "Download of all issues from the issue tracker has failed"
    popd > /dev/null 2>&1

    # Check whether expected files exist
    [ -s "$issues_file" ] || die "$issues_file does not exist or it is empty"
}

#
# Exercises the vcs-log-xref.pl script.
#
test_crossref_commmit_issue() {
    [ $# -eq 4 ] || die "Usage: ${FUNCNAME[0]} <project_id> <project_name> <work_dir> <regex>"

    local project_id="$1"
    local project_name="$2"
    local work_dir="$3"
    local regex="$4"

    local git_log_file="$work_dir/gitlog"
    local repository_dir="$work_dir/project_repos/$project_name.git"
    local issues_file="$work_dir/issues.txt"
    local commit_db_file="$work_dir/framework/projects/$project_id/$BUGS_CSV_ACTIVE"

    git --git-dir="$repository_dir" log --reverse > "$git_log_file" || die "Git log has failed"

    pushd . > /dev/null 2>&1
    cd "$BUG_MINING_FRAMEWORK_DIR"
    ./vcs-log-xref.pl -e "$regex" -l "$git_log_file" -r "$repository_dir" -i "$issues_file" -f "$commit_db_file" || die "Crossreference of commits and issues ids has failed"
    popd > /dev/null 2>&1

    # Check whether expected files exist
    [ -e "$commit_db_file" ] || die "$commit_db_file does not exist in $PWD"
    [ -s "$commit_db_file" ] || die "$commit_db_file is empty in $PWD"

    # Does each row contain 5 values?
    while read -r row; do
        num_columns=$(echo "$row" | tr ',' '\n' | wc -l)
        [ "$num_columns" -eq "5" ] || die "Row '$row' of $commit_db_file file is malformed"
    done < <(cat "$commit_db_file")
}

#
# Exercises the initialize-revisions.pl script.
#
test_initialize_revisions() {
    [ $# -eq 3 ] || die "Usage: ${FUNCNAME[0]} <project_id> <work_dir> <bug_id>"

    local project_id="$1"
    local work_dir="$2"
    local bug_id="$3"

    # Fix for Java-7
    local lib_dir="$work_dir/framework/projects/$project_id/lib"
    mkdir -p "$lib_dir"

    mkdir -p "$lib_dir/junit/junit/4.12"
    (cd "$lib_dir/junit/junit/4.12" && download_url https://repo1.maven.org/maven2/junit/junit/4.12/junit-4.12.jar) || die "Failed to download junit-4.12.jar"
    mkdir -p "$lib_dir/org/apache/commons/commons-lang3/3.4"
    (cd "$lib_dir/org/apache/commons/commons-lang3/3.4" && download_url https://repo1.maven.org/maven2/org/apache/commons/commons-lang3/3.4/commons-lang3-3.4.jar) || die "Failed to download commons-lang3-3.4.jar"
    mkdir -p "$lib_dir/org/hamcrest/hamcrest-core/1.3"
    (cd "$lib_dir/org/hamcrest/hamcrest-core/1.3" && download_url https://repo1.maven.org/maven2/org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar) || die "Failed to download hamcrest-core-1.3.jar"
    # End of fix for Java-7

    pushd . > /dev/null 2>&1
    cd "$BUG_MINING_FRAMEWORK_DIR"
    ./initialize-revisions.pl -p "$project_id" -w "$work_dir" -b "$bug_id" || die "Initialize revisions script has failed"
    popd > /dev/null 2>&1

    local analyzer_output_dir="framework/projects/$project_id/analyzer_output/$bug_id"
    [ -d "$work_dir/$analyzer_output_dir" ] || die "$work_dir/$analyzer_output_dir directory does not exist"
    _check_output "$work_dir/$analyzer_output_dir/developer-included-tests" "$RESOURCES_OUTPUT_DIR/$analyzer_output_dir/developer-included-tests"
    _check_output "$work_dir/$analyzer_output_dir/excludes" "$RESOURCES_OUTPUT_DIR/$analyzer_output_dir/excludes"
    _check_output "$work_dir/$analyzer_output_dir/includes" "$RESOURCES_OUTPUT_DIR/$analyzer_output_dir/includes"
    _check_output "$work_dir/$analyzer_output_dir/info" "$RESOURCES_OUTPUT_DIR/$analyzer_output_dir/info"

    local commit_db_file="$work_dir/framework/projects/$project_id/$BUGS_CSV_ACTIVE"
    local rev_v1; rev_v1=$(grep "^$bug_id," "$commit_db_file" | cut -f2 -d',')
    local rev_v2; rev_v2=$(grep "^$bug_id," "$commit_db_file" | cut -f3 -d',')
    local rev_v1_build_dir; rev_v1_build_dir="$work_dir/framework/projects/$project_id/build_files/$rev_v1"
    local rev_v2_build_dir; rev_v2_build_dir="$work_dir/framework/projects/$project_id/build_files/$rev_v2"
    [ -s "$rev_v1_build_dir/build.xml" ] || die "$rev_v1_build_dir/build.xml does not exist or it is empty"
    [ -s "$rev_v1_build_dir/maven-build.properties" ] || die "$rev_v1_build_dir/maven-build.properties does not exist or it is empty"
    [ -s "$rev_v1_build_dir/maven-build.xml" ] || die "$rev_v1_build_dir/maven-build.xml does not exist or it is empty"
    [ -s "$rev_v2_build_dir/build.xml" ] || die "$rev_v2_build_dir/build.xml does not exist or it is empty"
    [ -s "$rev_v2_build_dir/maven-build.properties" ] || die "$rev_v2_build_dir/maven-build.properties does not exist or it is empty"
    [ -s "$rev_v2_build_dir/maven-build.xml" ] || die "$rev_v2_build_dir/maven-build.xml does not exist or it is empty"

    local src_patch="framework/projects/$project_id/patches/$bug_id.src.patch"
    local test_patch="framework/projects/$project_id/patches/$bug_id.test.patch"
    _check_output "$work_dir/$src_patch" "$RESOURCES_OUTPUT_DIR/$src_patch"
    _check_output "$work_dir/$test_patch" "$RESOURCES_OUTPUT_DIR/$test_patch"

    local layout="framework/projects/$project_id/$LAYOUT_FILE"
    _check_output "$work_dir/$layout" "$RESOURCES_OUTPUT_DIR/$layout"
}

#
# Exercises the analyze-project.pl script.
#
test_analyze_project() {
    [ $# -eq 5 ] || die "Usage: ${FUNCNAME[0]} <project_id> <work_dir> <issue_tracker_name> <issue_tracker_project_id> <bug_id>"

    local project_id="$1"
    local work_dir="$2"
    local issue_tracker_name="$3"
    local issue_tracker_project_id="$4"
    local bug_id="$5"

    pushd . > /dev/null 2>&1
    cd "$BUG_MINING_FRAMEWORK_DIR"
    ./analyze-project.pl -p "$project_id" -w "$work_dir" -g "$issue_tracker_name" -t "$issue_tracker_project_id" -b "$bug_id" || die "Analyze project script has failed"
    popd > /dev/null 2>&1

    local commit_db_file="$work_dir/framework/projects/$project_id/$BUGS_CSV_ACTIVE"
    local rev_v2; rev_v2=$(grep "^$bug_id," "$commit_db_file" | cut -f3 -d',')
    local failing_tests="framework/projects/$project_id/failing_tests/$rev_v2"
    if [ -e "$RESOURCES_OUTPUT_DIR/$failing_tests" ]; then
        [ -s "$work_dir/$failing_tests" ] || die "No failing test cases has been reported"
    
        # Same number of failing tests
        local actual_num_failing_tests; actual_num_failing_tests=$(grep -c -a "^--- " "$work_dir/$failing_tests")
        local expected_num_failing_tests; expected_num_failing_tests=$(grep -c -a "^--- " "$RESOURCES_OUTPUT_DIR/$failing_tests")
        if [ "$actual_num_failing_tests" -ne "$expected_num_failing_tests" ]; then
          echo "Expected failing tests:"
          grep -a "^--- " "$RESOURCES_OUTPUT_DIR/$failing_tests"
    
          echo "Actual failing tests:"
          grep -a "^--- " "$work_dir/$failing_tests"
    
          die "Expected $expected_num_failing_tests failing tests and got $actual_num_failing_tests"
        fi
    
        # Same failing tests
        while read -r failing_test; do
            grep -q "^$failing_test$" "$RESOURCES_OUTPUT_DIR/$failing_tests" || die "Unexpected failing test case: '$failing_test'"
        done < <(grep -a "^--- " "$work_dir/$failing_tests")
    fi
}

#
# Exercises the get-trigger.pl script.
#
test_get_trigger() {
    [ $# -eq 3 ] || die "Usage: ${FUNCNAME[0]} <project_id> <work_dir> <bug_id>"

    local project_id="$1"
    local work_dir="$2"
    local bug_id="$3"

    pushd . > /dev/null 2>&1
    cd "$BUG_MINING_FRAMEWORK_DIR"
    ./get-trigger.pl -p "$project_id" -w "$work_dir" -b "$bug_id" || die "Get list of triggering test cases has failed"
    popd > /dev/null 2>&1

    local trigger_tests="framework/projects/$project_id/trigger_tests/$bug_id"
    [ -s "$work_dir/$trigger_tests" ] || die "List of triggering test cases is empty or does not exist"

    # Same number of trigger tests
    local actual_num_trigger_tests; actual_num_trigger_tests=$(grep -c -a "^--- " "$work_dir/$trigger_tests")
    local expected_num_trigger_tests; expected_num_trigger_tests=$(grep -c -a "^--- " "$RESOURCES_OUTPUT_DIR/$trigger_tests")
    [ "$actual_num_trigger_tests" -eq "$expected_num_trigger_tests" ] || die "Expected $expected_num_trigger_tests trigger tests and got $actual_num_trigger_tests"

    # Same trigger tests
    while read -r trigger_test; do
        grep -q "^$trigger_test$" "$RESOURCES_OUTPUT_DIR/$trigger_tests" || die "Unexpected trigger test case: '$trigger_test'"
    done < <(grep -a "^--- " "$work_dir/$trigger_tests")
}

#
# Exercises the get-metadata.pl script.
#
test_get_metadata() {
    [ $# -eq 3 ] || die "Usage: ${FUNCNAME[0]} <project_id> <work_dir> <bug_id>"

    local project_id="$1"
    local work_dir="$2"
    local bug_id="$3"

    pushd . > /dev/null 2>&1
    cd "$BUG_MINING_FRAMEWORK_DIR"
    ./get-metadata.pl -p "$project_id" -w "$work_dir" -b "$bug_id" || die "Metadata extraction has failed"
    popd > /dev/null 2>&1

    local relevant_tests="framework/projects/$project_id/relevant_tests/$bug_id"
    local modified_classes="framework/projects/$project_id/modified_classes/$bug_id.src"
    local loaded_classes="framework/projects/$project_id/loaded_classes/$bug_id.src"
    local loaded_test_classes="framework/projects/$project_id/loaded_classes/$bug_id.test"
    [ -s "$work_dir/$relevant_tests" ] || die "List of relevant test cases is empty or does not exist"
    [ -s "$work_dir/$modified_classes" ] || die "List of modified classes is empty or does not exist"
    [ -s "$work_dir/$loaded_classes" ] || die "List of loaded classes is empty or does not exist"
    [ -s "$work_dir/$loaded_test_classes" ] || die "List of loaded test classes is empty or does not exist"
    _check_output "$work_dir/$relevant_tests" "$RESOURCES_OUTPUT_DIR/$relevant_tests"
    _check_output "$work_dir/$modified_classes" "$RESOURCES_OUTPUT_DIR/$modified_classes"
    _check_output "$work_dir/$loaded_classes" "$RESOURCES_OUTPUT_DIR/$loaded_classes"
    _check_output "$work_dir/$loaded_test_classes" "$RESOURCES_OUTPUT_DIR/$loaded_test_classes"
}

#
# Exercises the promote-to-db.pl script.
#
test_promote_to_db() {
    [ $# -eq 4 ] || die "Usage: ${FUNCNAME[0]} <project_id> <project_name> <work_dir> <bug_id>"

    local project_id="$1"
    local project_name="$2"
    local work_dir="$3"
    local bug_id="$4"

    local repository_dir="$work_dir/project_repos/$project_name.git"

    pushd . > /dev/null 2>&1
    cd "$BUG_MINING_FRAMEWORK_DIR"
    ./promote-to-db.pl -p "$project_id" -w "$work_dir" -r "$repository_dir" -b "$bug_id" || die "Promotion of $project_id-$bug_id has failed"
    popd > /dev/null 2>&1

    _check_output "$HERE/../core/Project/$project_id.pm" "$work_dir/framework/core/Project/$project_id.pm"

    [ -d "$HERE/../projects/$project_id" ] || die "Project directory does not exist"

    local commit_db_file="$work_dir/framework/projects/$project_id/$BUGS_CSV_ACTIVE"
    local rev_v1; rev_v1=$(grep "^$bug_id," "$commit_db_file" | cut -f2 -d',')
    local rev_v2; rev_v2=$(grep "^$bug_id," "$commit_db_file" | cut -f3 -d',')

    local failing_tests="projects/$project_id/failing_tests/$rev_v2"
    _check_output "$HERE/../$failing_tests" "$work_dir/framework/$failing_tests"

    for dir in "build_files/$rev_v1" "build_files/$rev_v2"; do
        while read -r f; do
            f_name=$(basename "$f")
            _check_output "$HERE/../projects/$project_id/$dir/$f_name" "$f"
        done < <(find "$(cd "$work_dir/framework/projects/$project_id/$dir"; pwd)" -type f)
    done

    local loaded_classes="projects/$project_id/loaded_classes"
    _check_output "$HERE/../$loaded_classes/1.src" "$work_dir/framework/$loaded_classes/$bug_id.src"
    _check_output "$HERE/../$loaded_classes/1.test" "$work_dir/framework/$loaded_classes/$bug_id.test"

    local modified_classes="projects/$project_id/modified_classes"
    _check_output "$HERE/../$modified_classes/1.src" "$work_dir/framework/$modified_classes/$bug_id.src"

    local patches="projects/$project_id/patches"
    _check_output "$HERE/../$patches/1.src.patch" "$work_dir/framework/$patches/$bug_id.src.patch"
    _check_output "$HERE/../$patches/1.test.patch" "$work_dir/framework/$patches/$bug_id.test.patch"

    local relevant_tests="projects/$project_id/relevant_tests"
    _check_output "$HERE/../$relevant_tests/1" "$work_dir/framework/$relevant_tests/$bug_id"

    local trigger_tests="projects/$project_id/trigger_tests"
    _check_output "$HERE/../$trigger_tests/1" "$work_dir/framework/$trigger_tests/$bug_id"

    local project_build_xml="projects/$project_id/$project_id.build.xml"
    _check_output "$HERE/../$project_build_xml" "$work_dir/framework/$project_build_xml"

    [ -s "$HERE/../projects/$project_id/$BUGS_CSV_ACTIVE" ] || die "active-bugs csv does not exist or it is empty"
    [ -s "$HERE/../projects/$project_id/$BUGS_CSV_DEPRECATED" ] || die "deprecated-bugs csv does not exist or it is missing the header"
    [ -s "$HERE/../projects/$project_id/$LAYOUT_FILE" ] || die "$LAYOUT_FILE does not exist or it is empty"
}

#
# Exercises the promoted bug.
#
test_integration() {
    [ $# -eq 2 ] || die "Usage: ${FUNCNAME[0]} <project_id> <bug_id>"

    local project_id="$1"
    local bug_id="$2"

    ./test_verify_bugs.sh -p "$project_id" -b "$bug_id" || die "Verify script has failed"
}

main
