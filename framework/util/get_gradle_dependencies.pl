#!/usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2024 René Just, Darioush Jalali, and Defects4J contributors.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

=pod

=head1 NAME

get_gradle_dependencies.pl -- obtain a list of all gradle versions used in the
entire history of a particular project and collect all gradle dependencies
required to compile all bugs of that project.

=head1 SYNOPSIS

  get_gradle_dependencies.pl -p project_id

=head1 OPTIONS

=over 4

=item -p C<project_id>

The id of the project for which the list of gradle dependencies is extracted and
all gradle dependencies are collected.

=back

=head1 DESCRIPTION

Extracts all references to gradle distributions from the project's version
control history and collects all gradle dependencies required to compile all
bugs that project.

B<TODO: This script currently only works for git repositories!>

=cut

use warnings;
use strict;

use FindBin;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Project;

#
# Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('p:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p};

my $PID = $cmd_opts{p};

# Set up project
my $project = Project::create_project($PID);
my $repo = $project->{_vcs}->{repo};
my $cmd = "git -C $repo log -p -- gradle/wrapper/gradle-wrapper.properties | grep distributionUrl";

# Parse the vcs history and grep for distribution urls
my $log;
Utils::exec_cmd($cmd, "Obtaining all gradle dependencies", \$log);

# Process the list and remove duplicates
my %all_deps;
foreach (split(/\n/, $log)) {
    /[+-]distributionUrl=(.+)/ or die "Unexpected line extracted: $_!";
    my $url = $1;
    $url =~ s/\\:/:/g;
    $all_deps{$url} = 1;
}

# Print the ordered list of dependencies to STDOUT
print(join("\n", sort(keys(%all_deps))), "\n");

#
# Collect all gradle dependencies required to compile all bugs of a particular
# project
#

# Set up temporary directory
my $TMP_DIR = Utils::get_tmp_dir();
if (system("mkdir -p $TMP_DIR") != 0) {
    die "Could not create $TMP_DIR directory";
}

my @l_time = localtime(time);
my $month = 1 + $l_time[4]; # the month, i.e., [4] is in the range 0..11 , with 0 indicating January and 11 indicating December
my $year = 1900 + $l_time[5]; # $year, i.e., [5] contains the number of years since 1900

my $GRADLE_BUILD_SYSTEMS_LIB_DIR = "$BUILD_SYSTEMS_LIB_DIR/gradle";
if (system("mkdir -p $GRADLE_BUILD_SYSTEMS_LIB_DIR") != 0) {
    die "Could not create $GRADLE_BUILD_SYSTEMS_LIB_DIR";
}

my $GRADLE_DEPS_DIR = "$TMP_DIR/deps";
my $GRADLE_DEPS_README = "$GRADLE_DEPS_DIR/README.md";
my $GRADLE_DEPS_ZIP = "$GRADLE_BUILD_SYSTEMS_LIB_DIR/defects4j-gradle-deps.zip";

if (-e "$GRADLE_DEPS_ZIP") {
    # Unzip existing cache so that can be updated with new dependencies
    if (system("unzip -q -u $GRADLE_DEPS_ZIP -d $TMP_DIR") != 0) {
        die "Could not unzip $GRADLE_DEPS_ZIP";
    }
} else {
    if (system("mkdir -p $GRADLE_DEPS_DIR") != 0) {
        die "Could not create $GRADLE_DEPS_DIR directory";
    }
}

system("echo \"Gradle dependencies updated: ${month}/${year}\\n\" > $GRADLE_DEPS_README");

my @ids = $project->get_bug_ids();
foreach my $bid (@ids) {
    # Checkout a project version
    my $vid = "${bid}f";
    $project->{prog_root} = "$TMP_DIR/$PID-$vid";
    $project->checkout_vid($vid) or die "Could not checkout $PID-${vid}";

    # Compile the project using the D4J API (this step should force the download
    # of all dependencies to a local gradle directory)
    $project->compile() or die "Could not compile source code";
    $project->compile_tests() or die "Could not compile test suites";

    my $gradle_caches_dir = "$project->{prog_root}/$GRADLE_LOCAL_HOME_DIR/caches/modules-2/files-2.1";
    if (! -d $gradle_caches_dir) {
        next;
    }

    # Collect all dependencies

    # Convert pom and jar files from, e.g.,
    # $gradle_caches_dir/org.ow2.asm/asm/5.0.4/b4b92f4b84715dec57de734ff4c3098aa6904d06/asm-5.0.4.pom
    # $gradle_caches_dir/org.ow2.asm/asm/5.0.4/da08b8cce7bbf903602a25a3a163ae252435795/asm-5.0.4.jar
    # to
    # $GRADLE_DEPS_DIR/org/ow2/asm/asm/5.0.4/asm-5.0.4.pom
    # $GRADLE_DEPS_DIR/org/ow2/asm/asm/5.0.4/asm-5.0.4.jar
    my $log = "";
    my $cmd = "cd $gradle_caches_dir && \
            find . -type f | while read -r f; do \
                d=\$(dirname \$f) \
                mv \"\$f\" \"\$d/../\" \
            done \
            for d in \$(find . -mindepth 1 -maxdepth 1 -type d -printf '%f\\n'); do \
                artifact_dir=$GRADLE_DEPS_DIR/\$(echo \$d | tr '.' '/') \
                mkdir -p \$artifact_dir && \
                (cd \$d && cp -u -R . \$artifact_dir) \
            done";
    Utils::exec_cmd($cmd, "Collecting all project dependencies", \$log);

    # Remove checkout dir
    if (system("rm -rf $project->{prog_root}") != 0) {
        die "Could not remove $project->{prog_root}";
    }
}

# Updated README file with all dependencies
system("cd $GRADLE_DEPS_DIR && find * -type f ! -name 'README.md' -exec echo {} >> $GRADLE_DEPS_README \\;");

# Zip gradle dependencies
if (system("cd $TMP_DIR && find deps -type d -empty -delete && zip -q -r $GRADLE_DEPS_ZIP deps") != 0) {
    die "Could not zip $TMP_DIR/deps";
}

# Clean up
system("rm -rf $TMP_DIR");

# Make sure that all (new) gradle dependencies will be available to allow the
# user to compile any project version that is gradle-based
if (! -e "$GRADLE_DEPS_ZIP") {
    die "Could not find '$GRADLE_DEPS_ZIP' therefore no gradle distribution is available";
}
if (system("unzip -q -u $GRADLE_DEPS_ZIP -d $GRADLE_BUILD_SYSTEMS_LIB_DIR") != 0) {
    die "Could not unzip $GRADLE_DEPS_ZIP to $GRADLE_BUILD_SYSTEMS_LIB_DIR";
}
