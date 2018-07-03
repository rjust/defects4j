#!/usr/bin/env bash
#
################################################################################
# This script computes the total sloc for all bug-related classes on the buggy
# version. For each Defects4J project, it creates a file name <bid>.sloc under
# D4J_HOME/framework/projects/<pid>/slocs/ with the following format:
#
#   sloc_modified_classes,sloc_all_classes
#   13269,96382
#
# By default, the script computes the total sloc for all Defects4J projects and
# bugs. To only compute the total sloc for a specific project-bug run:
#
#   $ get_sloc.sh <project> <bug id>
#
# For example:
#
#   $ get_sloc.sh Chart 1
#
# Requirements:
# - the environment variable D4J_HOME needs to be set and must point to the
#   Defects4J installation.
# - sloccount tool must be installed and on the PATH.
#
################################################################################

#
# Print error message and exit
#
die() {
    echo "$1"
    exit 1
}

#
# Compute the total sloc of a specific project-bug
#
_compute_sloc() {
    local USAGE="Usage: _compute_sloc <project> <bug id>"
    if [ "$#" -ne "2" ]; then
        echo "$USAGE" >&2
        return 1
    fi

    local pid="$1"
    local bid="$2"

    # Temporary directory, used to checkout the buggy and fixed version
    local tmp_dir="/tmp/get_sloc_$$"
    rm -rf "$tmp_dir"; mkdir -p "$tmp_dir"
    local work_dir="$tmp_dir/$pid-$bid"
    mkdir -p "$work_dir"

    # Sloc file
    local sloc_dir="$D4J_HOME/framework/projects/$pid/slocs"
    [ -d "$sloc_dir" ] || mkdir -p "$sloc_dir"
    local sloc_file="$sloc_dir/$bid.sloc"
    echo "sloc_modified_classes,sloc_all_classes" > "$sloc_file"

    # Get project-bug
    "$D4J_HOME/framework/bin/defects4j" checkout -p "$pid" -v "${bid}b" -w "$work_dir" || return 1

    # Set of all bug-related classes
    local rel_classes=$(cat "$D4J_HOME/framework/projects/$pid/loaded_classes/$bid.src")
    # Set of modified classes (i.e., patched files)
    local src_dir=$(grep "d4j.dir.src.classes=" "$work_dir/defects4j.build.properties" | cut -f2 -d'=')

    # Temporary directory that holds all bug-related classes -- used to compute the
    # overall number of lines of code
    local dir_src="$tmp_dir/loc-$pid-$bid"
    mkdir -p "$dir_src"
    for class in $rel_classes; do
        src_file="$(echo $class | tr '.' '/').java";
        to_file="$(echo $src_file | tr '/' '-')";

        # Checkout the buggy project version
        [ -f  "$work_dir/$src_dir/$src_file" ] && cp "$work_dir/$src_dir/$src_file" "$dir_src/$to_file"
    done

    # Run sloccount and report total sloc
    local sloc=$(sloccount "$dir_src" | grep "java=\d*" | cut -f1 -d' ')
    local sloc_total=$(sloccount "$work_dir/$src_dir" | grep "java=\d*" | cut -f1 -d' ')
    echo "$sloc,$sloc_total" >> "$sloc_file"

    rm -rf "$tmp_dir"
    return 0
}

# Check whether D4J_HOME is set
[ "$D4J_HOME" != "" ] || die "[ERROR] D4J_HOME is not set!"
# Check whether sloccount command is available
if ! sloccount --version > /dev/null 2>&1; then
    die "[ERROR] Could not find 'sloccount' command! In order to compute the total sloc for all bug-related classes, sloccount must be installed and on the PATH. Please visit https://www.dwheeler.com/sloccount/ for instructions on how to install it."
fi

# Check command-line arguments
if [ "$#" -eq "2" ]; then
    _compute_sloc "$1" "$2" || die "[ERROR] get_sloc.sh failed for $1-$2"
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
        _compute_sloc "$pid" "$bid" || die "[ERROR] get_sloc.sh failed for $pid-$bid"
    done
done

exit 0

# EOF

