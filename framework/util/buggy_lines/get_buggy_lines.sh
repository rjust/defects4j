#!/usr/bin/env bash
#
################################################################################
# This script determines all buggy source code lines in a buggy Defects4J project
# version. It writes the result to a file named <bid>.buggy.lines under the
# project directory, i.e., D4J_HOME/framework/projects/<pid>/buggy_lines/. By
# default, the scripts determines all buggy source code lines for all Defects4J
# projects and versions. To only determine all buggy source code lines of a
# specific Defects4J project version, run:
#
#   $ get_buggy_lines.sh <project> <bug id>
#
# For example:
#
#   $ get_buggy_lines.sh Chart 1
#
#
# Considering removed and added lines (from buggy to fixed), the script works as
# follows:
#
# 1) For each removed line, the script outputs the line number of the removed
#    line.
#
# 2) For each block of added lines, the script distinguishes two cases:
#    2.1) If the block of added lines is immediately preceded by a removed line,
#         the block is associated with that preceding line -- the script does not
#         output a line number in this case.
#    2.2) If the block of added lines is not immediately preceded by a removed
#         line, the script outputs the line number of the line immediately
#         following the block of added lines.
#
# Examples:
#
# Case 1) -- output: line 2
# buggy        fixed
# 1            1
# 2            
#
# Case 2.1) -- output: line 2
# buggy        fixed
# 1            1
# 2            20
#
# Case 2.1) -- output: line 2
# buggy        fixed
# 1            1
# 2            20
#              21
#              22
#
# Case 2.2) -- output: line 2
# buggy        fixed
# 1            1
#              10
#              11
# 2            2
#
# Requirements:
# - Bash 4+ needs to be installed
# - diff needs to be installed and on the PATH.
# - the environment variable D4J_HOME needs to be set and must point to the
#   Defects4J installation that contains all minimized patches.
# - Python >= 2.7
#
################################################################################

SCRIPT_DIR=$(cd `dirname $0` && pwd)

#
# Print error message and exit
#
die() {
    echo "$1"
    exit 1
}

#
# Determine all buggy lines, using the diff between the buggy and fixed version
#
_determine_buggy_lines() {
    local USAGE="Usage: _determine_buggy_lines <project> <bug id>"
    if [ "$#" -ne "2" ]; then
        echo "$USAGE" >&2
        return 1
    fi

    local pid="$1"
    local bid="$2"

    # Temporary directory, used to checkout the buggy and fixed version
    local tmp_dir="/tmp/get_buggy_lines_$$"
    rm -rf "$tmp_dir"; mkdir -p "$tmp_dir"

    # Temporary file, used to collect information about all removed and added lines
    local tmp_dir_lines="$tmp_dir/all_buggy_lines"

    # buggy_lines file
    local buggy_lines_dir="$D4J_HOME/framework/projects/$pid/buggy_lines"
    [ -d "$buggy_lines_dir" ] || mkdir -p "$buggy_lines_dir"
    local buggy_lines_file="$buggy_lines_dir/$bid.buggy.lines"
    rm -f "$buggy_lines_file"

    local work_dir="$tmp_dir/$pid-$bid"
    mkdir -p "$work_dir"

    # Checkout the fixed project version
    "$D4J_HOME/framework/bin/defects4j" checkout -p "$pid" -v "${bid}f" -w "${work_dir}f" || return 1
    local src_dir=$(grep "d4j.dir.src.classes=" "${work_dir}f/defects4j.build.properties" | cut -f2 -d'=')

    # Checkout the buggy project version
    "$D4J_HOME/framework/bin/defects4j" checkout -p "$pid" -v "${bid}b" -w "${work_dir}b" || return 1

    # Determine and iterate over all modified classes (i.e., patched files)
    local modified_classes=$(cat "$D4J_HOME/framework/projects/$pid/modified_classes/$bid.src")
    for class in $modified_classes; do
        local java_file="$(echo $class | tr '.' '/').java";

        cp "${work_dir}f/$src_dir/$java_file" "$tmp_dir/fixed"
        cp "${work_dir}b/$src_dir/$java_file" "$tmp_dir/buggy"

        # Diff between buggy and fixed -- only show line numbers for removed and
        # added lines in the buggy version
        diff --unchanged-line-format='' \
             --old-line-format="$java_file#%dn#%l%c'\12'" \
             --new-group-format="$java_file#%df#FAULT_OF_OMISSION%c'\12'" \
             "$tmp_dir/buggy" "$tmp_dir/fixed" >> "$tmp_dir_lines"
    done

    # Print all removed lines to output file
    grep --text -v "FAULT_OF_OMISSION" "$tmp_dir_lines" > "$buggy_lines_file"

    # Check which added lines need to be added to the output file
    for entry in $(grep --text 'FAULT_OF_OMISSION' "$tmp_dir_lines"); do
        # Determine whether file#line already exists in output file -> if so, skip
        local line=$(echo $entry | cut -f1,2 -d'#')
        grep -q "$line" "$buggy_lines_file" || echo "$entry" >> "$buggy_lines_file"
    done

    # In case there are any FAULT_OF_OMISSION, a candidate would have to be
    # provided by a human
    local candidates_file="$buggy_lines_dir/$bid.candidates"
    rm -f "$candidates_file"
    python "$SCRIPT_DIR/ask_for_candidates.py" \
        --buggy-directory "${work_dir}b" \
        --fixed-directory "${work_dir}f" \
        --src-dir "$src_dir" \
        --buggy-lines-file "$buggy_lines_file" \
        --candidates-file "$candidates_file" || return 1

    # Analyse which buggy lines can be ranked
    local unrankable_lines_file="$buggy_lines_dir/$bid.unrankable.lines"
    rm -f "$unrankable_lines_file"
    python "$SCRIPT_DIR/note_unrankable_lines.py" \
        --buggy-lines-file "$buggy_lines_file" \
        --candidates-file "$candidates_file" \
        --unrankable-lines-file "$unrankable_lines_file" || return 1

    if [ -f "$unrankable_lines_file" ]; then
      # In case there are some unrankable lines warn the user in case
      # all buggy lines have been considered unrankable
      local num_buggy_lines=$(wc -l "$buggy_lines_file" | cut -f1 -d' ')
      local num_unrankable_lines=$(wc -l "$unrankable_lines_file" | cut -f1 -d' ')
      if [ "$num_buggy_lines" -eq "$num_unrankable_lines" ]; then
        echo "[WARN] All buggy lines have been considered unrankable."
      fi
    fi

    rm -rf "$tmp_dir"
    return 0
}

# Check whether D4J_HOME is set
[ "$D4J_HOME" != "" ] || die "[ERROR] D4J_HOME is not set!"
# Check whether diff command is available
if ! diff --version > /dev/null 2>&1; then
    die "[ERROR] Could not find 'diff' command! In order to compute all buggy lines, diff must be installed and on the PATH to determine the diff between the buggy and fixed version."
fi

# Check command-line arguments
if [ "$#" -eq "2" ]; then
    _determine_buggy_lines "$1" "$2" || die "[ERROR] get_buggy_lines.sh failed for $1-$2"
    exit 0
elif [ "$#" -ne "0" ]; then
    die "Usage: $0"
fi

# Default behaviour, i.e., all projects and bugs
for pid in Chart Closure Lang Math Mockito Time; do
    dir_project="$D4J_HOME/framework/projects/$pid"

    # Determine and iterate over all bugs
    bids=$(cut -f1 -d',' $dir_project/commit-db)
    for bid in $bids; do
        _determine_buggy_lines "$pid" "$bid" || die "[ERROR] get_buggy_lines.sh failed for $pid-$bid"
        if [ $? -ne 0 ]; then
          die "[ERROR] _determine_buggy_lines failed for $pid-$bid!"
        fi
    done
done

exit 0

# EOF

