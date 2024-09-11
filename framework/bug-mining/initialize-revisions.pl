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

initialize-revisions.pl -- Initialize all revisions: identify the directory
layout and perform a sanity check for each revision.

=head1 SYNOPSIS

initialize-revisions.pl -p project_id -w work_dir [-s subproject] [ -b bug_id] [-D]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the project for which the meta data should be generated.

=item B<-w F<work_dir>>

The working directory used for the bug-mining process.

=item B<-s F<subproject>>

The subproject to be mined (if not the root directory)

=item B<-b C<bug_id>>

Only analyze this bug id. The bug_id has to follow the format B<(\d+)(:(\d+))?>.
Per default all bug ids, listed in the active-bugs csv, are considered.

=item B<-D>

Debug: Enable verbose logging and do not delete the temporary check-out directory
(optional).

=back

=cut
use warnings;
use strict;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;
use Project;
use DB;
use Utils;

my %cmd_opts;
getopts('p:b:w:s:D', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{w};

my $PID = $cmd_opts{p};
my $BID = $cmd_opts{b};
my $WORK_DIR = abs_path($cmd_opts{w});
my $SUBPROJ = $cmd_opts{s};
$DEBUG = 1 if defined $cmd_opts{D};

# Check format of target bug id
if (defined $BID) {
    $BID =~ /^(\d+)(:(\d+))?$/ or die "Wrong version id format ((\\d+)(:(\\d+))?): $BID!";
}

# Add script and core directory to @INC
unshift(@INC, "$WORK_DIR/framework/core");

# Override global constants
$REPO_DIR = "$WORK_DIR/project_repos";
$PROJECTS_DIR = "$WORK_DIR/framework/projects";

# Create necessary directories
my $PROJECT_DIR = "$PROJECTS_DIR/$PID";
my $PATCH_DIR   = "$PROJECT_DIR/patches";
my $ANALYZER_OUTPUT = "$PROJECT_DIR/analyzer_output";
my $GEN_BUILDFILE_DIR = "$PROJECT_DIR/build_files";

-d $PROJECT_DIR or die "$PROJECT_DIR does not exist: $!";
-d $PATCH_DIR or die "$PATCH_DIR does not exist: $!";

system("mkdir -p $ANALYZER_OUTPUT $GEN_BUILDFILE_DIR");

# Temporary directory
my $TMP_DIR = Utils::get_tmp_dir();
system("mkdir -p $TMP_DIR");

# Set up project
my $project = Project::create_project($PID);

#
# Initialize a specific version id.
#
sub _init_version {
    my ($project, $bid, $vid) = @_;

    my $work_dir = "${TMP_DIR}/${vid}";
    $project->{prog_root} = $work_dir;

    my $rev_id = $project->lookup("${vid}");

    # Use the VCS checkout routine, which does not apply the cached, possibly
    # minimized patch to obtain the buggy version.
    $project->{_vcs}->checkout_vid("${vid}", $work_dir) or die "Cannot checkout $vid version";

    if (defined $SUBPROJ) {
        $work_dir .= "/$SUBPROJ/";
        $project->{prog_root} = $work_dir;
    }

    system("mkdir -p $ANALYZER_OUTPUT/$bid");

    _init_maven($work_dir, $bid, $rev_id) or _init_ant($work_dir, $bid, $rev_id) or die "Unsupported build system";

    $project->initialize_revision($rev_id, "${vid}");

    return ($rev_id, $project->src_dir("${vid}"), $project->test_dir("${vid}"));
}

#
# Init routine for Maven builds.
#
sub _init_maven {
    my ($work_dir, $bid, $rev_id) = @_;

    if (! -e "$work_dir/pom.xml") { return 0; }

    # If both pom.xml and build.xml are present, rely on the pom.xml.
    if (-e "$work_dir/build.xml") {
        rename("$work_dir/build.xml", "$work_dir/build.xml.orig") or die "Cannot backup existing Ant build file: $!";
    }

    # Update the pom.xml to replace deprecated declarations.
    Utils::fix_dependency_urls("$work_dir/pom.xml", "$UTIL_DIR/fix_pom_dependency_urls.patterns", 1) if -e "$work_dir/pom.xml";
    
    # Run maven-ant plugin and overwrite the original build.xml whenever a maven build file exists
    my $cmd = " cd $work_dir" .
              " && mvn ant:ant -Doverwrite=true 2>&1 -Dhttps.protocols=TLSv1.2" .
              " && rm -rf $GEN_BUILDFILE_DIR/$rev_id && mkdir -p $GEN_BUILDFILE_DIR/$rev_id 2>&1" .
              " && cp maven-build.* $GEN_BUILDFILE_DIR/$rev_id 2>&1" .
              " && cp build.xml $GEN_BUILDFILE_DIR/$rev_id 2>&1";

    if (! Utils::exec_cmd($cmd, "Convert Maven to Ant build file: " . $rev_id)) {
        # Can't convert Maven to ant -> restore original Ant build file, which
        # will be tried next.
        if (-e "$work_dir/build.xml.orig") {
            rename("$work_dir/build.xml.orig", "$work_dir/build.xml") or die "Cannot restore existing Ant build file: $!";
        }
        return 0;
    }

    # Update the deprecated urls in the generated maven.build.xml
    for my $build_file (("maven-build.xml", "maven-build.properties")) {
        Utils::fix_dependency_urls("$work_dir/$build_file", "$UTIL_DIR/fix_dependency_urls.patterns", 0) if -e "$work_dir/$build_file";
    }

    $cmd = " cd $work_dir" .
           " && java -jar $LIB_DIR/analyzer.jar $work_dir $ANALYZER_OUTPUT/$bid maven-build.xml 2>&1";
    Utils::exec_cmd($cmd, "Run build-file analyzer on maven-ant.xml.") or die;

    # Get dependencies from the maven-build.xml
    my $download_dep = "cd $work_dir && ant -Dmaven.repo.local=\"$PROJECT_DIR/lib\" get-deps";
    Utils::exec_cmd($download_dep, "Download dependencies for maven-build.xml.");

    return 1;
}

#
# Init routine for Ant builds.
#
sub _init_ant {
    my ($work_dir, $bid, $rev_id) = @_;

    if (! -e "$work_dir/build.xml") { return 0; }

    my $cmd = " cd $work_dir" .
              " && java -jar $LIB_DIR/analyzer.jar $work_dir $ANALYZER_OUTPUT/$bid build.xml 2>&1";
    Utils::exec_cmd($cmd, "Run build-file analyzer on build.xml.");

    return 1;
}

#
# The Defects4J core framework requires certain metadata for each defect. This
# routine creates these artifacts, if necessary.
#
sub _bootstrap {
    my ($project, $bid) = @_;

    my ($v1, $src_b, $test_b) = _init_version($project, $bid, "${bid}b");
    my ($v2, $src_f, $test_f) = _init_version($project, $bid, "${bid}f");

    die "Source directories don't match for buggy and fixed revisions of $bid" unless $src_b eq $src_f;
    die "Test directories don't match for buggy and fixed revisions of $bid" unless $test_b eq $test_f;

    # Create local patch so that we can use the D4J core framework.
    # Minimization doesn't matter here, which has to be done manually.
    $project->export_diff($v2, $v1, "$PATCH_DIR/$bid.src.patch", "$src_f");
    $project->export_diff($v2, $v1, "$PATCH_DIR/$bid.test.patch", "$test_f");
}

my @ids = $project->get_bug_ids();
if (defined $BID) {
    if ($BID =~ /(\d+):(\d+)/) {
        @ids = grep { ($1 <= $_) && ($_ <= $2) } @ids;
    } else {
        # single bid
        @ids = grep { ($BID == $_) } @ids;
    }
}
foreach my $bid (@ids) {
    printf ("%4d: $project->{prog_name}\n", $bid);

    # Clean up previously generated data
    system("rm -rf $ANALYZER_OUTPUT/${bid} $PATCH_DIR/${bid}.src.patch $PATCH_DIR/${bid}.test.patch");

    # Populate the layout map and patches directory
    _bootstrap($project, $bid);

    # Defects4J cannot handle empty patch files -> skip the sanity check since
    # these candidates are filtered in a later step anyway.
    if (-z "$PATCH_DIR/$bid.src.patch") {
        printf("      -> Skipping sanity check (empty source patch)\n");
        next;
    }

    # Clean the temporary directory
    Utils::exec_cmd("rm -rf $TMP_DIR && mkdir -p $TMP_DIR", "Cleaning working directory")
            or die "Cannot clean working directory";
    $project->{prog_root} = $TMP_DIR;
    $project->checkout_vid("${bid}f", $TMP_DIR, 1) or die "Cannot checkout fixed version";
    $project->sanity_check();
}

# Create a sorted, unique list of inferred include/exclude patterns
system("cat $ANALYZER_OUTPUT/*/includes | sort -u | while read -r include; do echo \"<include name='\"\$include\"' />\"; done >  $ANALYZER_OUTPUT/inc_exc.patterns");
system("cat $ANALYZER_OUTPUT/*/excludes | sort -u | while read -r exclude; do echo \"<exclude name='\"\$exclude\"' />\"; done >> $ANALYZER_OUTPUT/inc_exc.patterns");
open(IN, "<$ANALYZER_OUTPUT/inc_exc.patterns") or die "Cannot open include/exclude patterns: $!";
  my @patterns = <IN>;
close(IN);

# Parse generated build file and insert inferred include/exclude patterns
my $build_file  = "$PROJECT_DIR/$PID.build.xml";
my @cache;
open(IN, "<$build_file") or die "Cannot open build file: $!";
while(<IN>) {
  if (/^(\s*)<!--###ADD_INC_EXC###/) {
    my $indent = $1;
    push(@cache, map { $indent . $_ } @patterns);
  } else {
    push(@cache, $_);
  }
}

# Overwrite the existing, generated build file
system("mv $build_file $build_file.bak") if $DEBUG;
open(OUT, ">$build_file");
foreach (@cache) {
  print(OUT $_);
}
close(OUT);

print("\nAdded the following entries to 'all.manual.tests' (in $build_file)\n");
system("cat $ANALYZER_OUTPUT/inc_exc.patterns");

system("rm -rf $TMP_DIR") unless $DEBUG;
