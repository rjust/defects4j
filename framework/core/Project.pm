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

Project.pm -- interface and abstraction for all projects.

=head1 SYNOPSIS

=head2 In Embedding Script:

A specific project instance can be created with C<create_project(project_id)>.

  use Project;
  my $pid=$ARGV[0];
  my $project = Project::create_project($pid);

=head2 New Project Submodule

  package Project::MyProject;

  use Constants;
  use Vcs::Git; # or Svn, etc.
  our @ISA = qw(Project);

  my $PID = "MyID";

  sub new {
    my ($class) = @_;
    my $name  = "my-project-name";
    my $vcs   = Vcs::Git->new($PID,
                              "$REPO_DIR/$name.git",
                              "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE");

    return $class->SUPER::new($PID, $name, $vcs);
}

=head1 DESCRIPTION

This module provides a general abstraction for attributes and subroutines of a project.
Every submodule of Project represents one of the open source projects in the database.

=head2 Available Project IDs

=over 4

=item * L<Chart|Project::Chart>

JFreeChart (L<Vcs::Svn> backend)

=item * L<Cli|Project::Cli>

Commons CLI (L<Vcs::Git> backend)

=item * L<Closure|Project::Closure>

Closure compiler (L<Vcs::Git> backend)

=item * L<Codec|Project::Codec>

Commons Codec (L<Vcs::Git> backend)

=item * L<Collections|Project::Collections>

Commons Collections (L<Vcs::Git> backend)

=item * L<Compress|Project::Compress>

Commons Compress (L<Vcs::Git> backend)

=item * L<Csv|Project::Csv>

Commons CSV (L<Vcs::Git> backend)

=item * L<Gson|Project::Gson>

Google Gson (L<Vcs::Git> backend)

=item * L<JacksonCore|Project::JacksonCore>

Jackson JSON Parser (L<Vcs::Git> backend)

=item * L<JacksonDatabind|Project::JacksonDatabind>

Jackson Data Bindings (L<Vcs::Git> backend)

=item * L<JacksonXml|Project::JacksonXml>

Jackson XML Parser (L<Vcs::Git> backend)

=item * L<Jsoup|Project::Jsoup>

Jsoup HTML Parser (L<Vcs::Git> backend)

=item * L<JxPath|Project::JxPath>

Commons JxPath (L<Vcs::Git> backend)

=item * L<Lang|Project::Lang>

Commons lang (L<Vcs::Git> backend)

=item * L<Math|Project::Math>

Commons math (L<Vcs::Git> backend)

=item * L<Mockito|Project::Mockito>

Mockito (L<Vcs::Git> backend)

=item * L<Time|Project::Time>

Joda-time (L<Vcs::Git> backend)

=back

=cut

package Project;

use warnings;
use strict;
use Constants;
use Utils;
use Mutation;
use Carp qw(confess);

=pod

=head2 Create an instance of a Project

  Project::create_project(project_id)

Dynamically loads the required submodule, instantiates the project, and returns a
reference to it.

=cut

sub create_project {
    @_ == 1 or die "$ARG_ERROR Use: create_project(project_id)";
    my ($pid) = @_;
    my $module = __PACKAGE__ . "/$pid.pm";
    my $class  = __PACKAGE__ . "::$pid";

    eval { require $module };
    die "Invalid project_id: $pid\n$@" if $@;

    return $class->new();
}

=pod

=head2 Object attributes

  $project->{prog_name}

The program name of the project.

  $project->{prog_root}

The root (working) directory for a checked-out program version of this project.

=cut

sub new {
    @_ == 4 or die $ARG_ERROR;
    my ($class, $pid, $prog, $vcs) = @_;

    my $self = {
        pid        => $pid,
        prog_name  => $prog,
        prog_root  => $ENV{PROG_ROOT} // "/tmp/${pid}_".time,
        _vcs       => $vcs,
    };
    bless $self, $class;
    $self->_cache_layout_map();
    return $self;
}

=pod

=head2 General subroutines

  $project->print_info()

Prints all general and project-specific properties to STDOUT.

=cut

sub print_info {
    @_ == 1 or die $ARG_ERROR;
    my ($self) = @_;
    my $pid = $self->{pid};
    print "Summary of configuration for Project: $pid\n";
    print "-"x80 . "\n";
    printf ("%14s: %s\n", "Script dir", $SCRIPT_DIR);
    printf ("%14s: %s\n", "Base dir", $BASE_DIR);
    printf ("%14s: %s\n", "Major root", $MAJOR_ROOT);
    printf ("%14s: %s\n", "Repo dir", $REPO_DIR);
    print "-"x80 . "\n";
    printf ("%14s: %s\n", "Project ID", $pid);
    printf ("%14s: %s\n", "Program", $self->{prog_name});
    printf ("%14s: %s\n", "Build file", "$PROJECTS_DIR/$pid/$pid.build.xml");
    print "-"x80 . "\n";
    printf ("%14s: %s\n", "Vcs", ref $self->{_vcs});
    printf ("%14s: %s\n", "Repository", $self->{_vcs}->{repo});
    printf ("%14s: %s\n", "Commit db", $self->{_vcs}->{commit_db});
    my @ids = $self->get_bug_ids();
    printf ("%14s: %s\n", "Number of bugs", scalar(@ids));
    print "-"x80 . "\n";
}

=pod

  $project->bug_report_id()

Returns the bug report ID of a given version id C<vid>.

=cut

sub bug_report_id {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    my $bug_report_info = Utils::bug_report_info($self->{pid}, $vid);
    return $bug_report_info->{id};
}

=pod

  $project->bug_report_url()

Returns the bug report URL of a given version id C<vid>.

=cut

sub bug_report_url {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    my $bug_report_info = Utils::bug_report_info($self->{pid}, $vid);
    return $bug_report_info->{url};
}

=pod

  $project->src_dir(vid)

Returns the path to the directory of the source files for a given version id C<vid>.
The returned path is relative to the working directory.

=cut

sub src_dir {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    my $revision_id = $self->lookup($vid);
    return $self->_determine_layout($revision_id)->{src};
}

=pod

  $project->test_dir(vid)

Returns the path to the directory of the junit test files for a given version id C<vid>.
The returned path is relative to the working directory.

=cut

sub test_dir {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    my $revision_id = $self->lookup($vid);
    return $self->_determine_layout($revision_id)->{test};
}

=pod

  $project->exclude_tests_in_file(file, tests_dir)

Excludes all tests listed in F<file> from the checked-out program version.
The test sources must exist in the C<tests_dir> directory, which is relative to the
working directory.

Tests are removed as follows:

=over 4

=item * All test methods listed in F<file> are removed from the source code.

=item * All test classes listed in F<file> are added to the exclude list in
F<"work_dir"/$PROP_FILE>.

=back

=cut

sub exclude_tests_in_file {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $file, $tests_dir) = @_;
    my $work_dir = $self->{prog_root};

    # Remove broken test methods
    Utils::exec_cmd("$UTIL_DIR/rm_broken_tests.pl $file $work_dir/$tests_dir",
            "Excluding broken/flaky tests") or die;

    # Check whether broken test classes should be excluded
    my $failed = Utils::get_failing_tests($file);
    my @classes= @{$failed->{classes}};

    return if scalar @classes == 0;
    for (@classes) {
        s/\./\//g;
        # Use ".*" as suffix because the file set of tests might be defined over
        # source or class files.
        s/(.*)/$1.*/;
    }
    # Write list of tests to exclude to properties file, which is
    # imported by the top-level build file.
    my $list = join(",", @classes);
    my $config = {$PROP_EXCLUDE => $list};
    Utils::write_config_file("$work_dir/$PROP_FILE", $config);
}


=pod

=head2 Build system related subroutines

  $project->sanity_check()

Checks whether the project is correctly configured.

=cut

sub sanity_check {
    @_ == 1 or die $ARG_ERROR;
    my ($self) = @_;
    return $self->_ant_call_comp("sanity.check");
}

=pod

  $project->checkout_vid(vid [, work_dir, is_bugmine])

Checks out the provided version id (C<vid>) to F<work_dir>, and tags the buggy AND
the fixed program version of this bug. Format of C<vid>: C<\d+[bf]>.
The temporary working directory (C<work_dir>) is optional, the default is C<prog_root> from the instance of this class.
The is_bugmine flag (C<is_bugmine>) is optional and indicates whether the
framework is used for bug mining, the default is false.

=cut

sub checkout_vid {
    my ($self, $vid, $work_dir, $is_bugmine) = @_;
    my $tmp = Utils::check_vid($vid);
    my $bid = $tmp->{bid};
    my $version_type = $tmp->{type};

    my $pid = $self->{pid};
    my $revision_id = $self->lookup("${bid}f");
    unless (defined $work_dir) {
        $work_dir = $self->{prog_root} ;
    }

    # Check whether the working directory can be re-used (same pid and bid)
    if (-e "$work_dir/$CONFIG") {
        # If the directory is a previously used working directory, check whether
        # we can just checkout a previously generated tag.
        my $config = Utils::read_config_file("$work_dir/$CONFIG");
        if (defined $config) {
            my $old_pid = $config->{$CONFIG_PID};
            my $old_vid = $config->{$CONFIG_VID};

            # TODO: Avoid re-cloning the repo if the pid didn't change but the
            #       bid did. We currently only re-use a working directory for
            #       the same pid and bid.
            if (_can_reuse_work_dir($pid, $vid, $old_pid, $old_vid)) {
                my $version_type = Utils::check_vid($vid)->{type};
                my $tag_name = Utils::tag_prefix($pid, $bid) .
                        ($version_type eq "b" ? $TAG_BUGGY : $TAG_FIXED);
                my $cmd = "cd $work_dir" .
                          " && git checkout $tag_name 2>&1" .
                          " && git clean -xdf 2>&1";
                # Simply checkout previously tagged version and return
                Utils::exec_cmd($cmd, "Check out program version: $pid-$vid")
                        or confess("Couldn't check out program version!");
                return 1;
            }
        }
    }

    $self->{_vcs}->checkout_vid("${bid}f", $work_dir) or return 0;

    # Init (new) git repository
    my $cmd = "cd $work_dir" .
              " && git init 2>&1" .
              " && git config user.name defects4j 2>&1" .
              " && git config user.email defects4j\@localhost 2>&1" .
              " && git config core.autocrlf false 2>&1";
    Utils::exec_cmd($cmd, "Init local repository")
            or confess("Couldn't init local git repository!");

    # Write program and version id of fixed program version to config file
    Utils::write_config_file("$work_dir/$CONFIG", {$CONFIG_PID => $pid, $CONFIG_VID => "${bid}f"});

    # Commit and tag the post-fix revision
    my $tag_name = Utils::tag_prefix($pid, $bid) . $TAG_POST_FIX;
    $cmd = "cd $work_dir" .
           " && git init 2>&1" .
           " && echo \".svn\" > .gitignore" .
           " && git add -A 2>&1" .
           " && git commit -a -m $tag_name 2>&1" .
           " && git tag $tag_name 2>&1";
    Utils::exec_cmd($cmd, "Tag post-fix revision")
            or confess("Couldn't tag post-fix revision!");

    # Check whether post-checkout hook is provided
    if (defined $self->{_vcs}->{_co_hook}) {
        # Execute post-checkout hook
        $self->{_vcs}->{_co_hook}($self, $revision_id, $work_dir);
        # TODO: We need a better solution for tracking changes of the
        # post-checkout hook.
        my $changes = `cd $work_dir && git status -s | wc -l`;
        $changes =~ /\s*(\d+)\s*/; $changes = $1;
        $? == 0 or confess("Inconsistent local repository!");
        # Anything to commit?
        if ($changes) {
            # Commit and tag the compilable post-fix revision
            my $tag_name = Utils::tag_prefix($pid, $bid) . $TAG_POST_FIX_COMP;
            $cmd = "cd $work_dir" .
                   " && git add -A 2>&1" .
                   " && git commit -a -m \"$tag_name\" 2>&1" .
                   " && git tag $tag_name 2>&1";
            Utils::exec_cmd($cmd, "Run post-checkout hook")
                    or confess("Couldn't tag version after applying checkout hook!");
        }
    }

    # Note: will skip both of these for bug mining, for two reasons:
    # (1) it isnt necessary and (2) we don't have dependencies yet.
    # Fix test suite if necessary
    $self->fix_tests("${bid}f");
    # Write version-specific properties
    $self->_write_props($vid, $is_bugmine);

    # Fix dependency URLs if necessary (we only fix this on the fixed version
    # since the buggy version is derived by applying a source-code patch).
    for my $build_file (("build.xml", "maven-build.xml", "pom.xml", "project.xml", "project.properties", "default.properties", "maven-build.properties")) {
        Utils::fix_dependency_urls("$work_dir/$build_file", "$UTIL_DIR/fix_dependency_urls.patterns", 0) if -e "$work_dir/$build_file";
    }

    # Commit and tag the fixed program version
    $tag_name = Utils::tag_prefix($pid, $bid) . $TAG_FIXED;
    $cmd = "cd $work_dir" .
           " && git add -A 2>&1" .
           " && git commit -a -m \"$tag_name\" 2>&1" .
           " && git tag $tag_name 2>&1";
    Utils::exec_cmd($cmd, "Initialize fixed program version")
            or confess("Couldn't tag fixed program version!");

    # Apply patch to obtain buggy version
    my $patch_dir =  "$PROJECTS_DIR/$pid/patches";
    my $src_patch = "$patch_dir/${bid}.src.patch";
    $self->apply_patch($work_dir, $src_patch) or return 0;

    # Write program and version id of buggy program version to config file
    Utils::write_config_file("$work_dir/$CONFIG", {$CONFIG_PID => $pid, $CONFIG_VID => "${bid}b"});

    # Commit and tag the buggy program version
    $tag_name = Utils::tag_prefix($pid, $bid) . $TAG_BUGGY;
    $cmd = "cd $work_dir" .
           " && git add -A 2>&1" .
           " && git commit -a -m \"$tag_name\" 2>&1" .
           " && git tag $tag_name 2>&1";
    Utils::exec_cmd($cmd, "Initialize buggy program version")
            or confess("Couldn't tag buggy program version!");

    # Checkout post-fix revision and apply unmodified diff to obtain the pre-fix revision
    my $tmp_file = "$work_dir/.defects4j.diff";
    $cmd = "cd $work_dir && git checkout " . Utils::tag_prefix($pid, $bid) . "$TAG_POST_FIX 2>&1";
    `$cmd`; $?==0 or confess("Couldn't checkout $TAG_POST_FIX");
    my $rev1 = $self->lookup("${bid}f");
    my $rev2 = $self->lookup("${bid}b");
    # TODO: svn doesn't support diffing of binary files
    #       -> checkout and tag the pre-fix revision instead
    $self->{_vcs}->export_diff($rev1, $rev2, $tmp_file);
    $self->{_vcs}->apply_patch($work_dir, $tmp_file);

    # Remove temporary diff file
    system("rm $tmp_file");

    # Commit and tag the pre-fix revision
    $tag_name = Utils::tag_prefix($pid, $bid) . $TAG_PRE_FIX;
    $cmd = "cd $work_dir" .
           " && git add -A 2>&1" .
           " && git commit -a -m \"$tag_name\" 2>&1" .
           " && git tag $tag_name 2>&1";
    Utils::exec_cmd($cmd, "Tag pre-fix revision")
            or confess("Couldn't tag pre-fix revision!");

    # Checkout the requested program version
    $tag_name = Utils::tag_prefix($pid, $bid) . ($version_type eq "b" ? $TAG_BUGGY : $TAG_FIXED);
    $cmd = "cd $work_dir && git checkout $tag_name 2>&1";
    Utils::exec_cmd($cmd, "Check out program version: $pid-$vid")
            or confess("Couldn't check out program version!");
    return 1;
}



=pod

  $project->compile([log_file])

Compiles the sources of the project version that is currently checked out.
If F<log_file> is provided, the compiler output is written to this file.

=cut

sub compile {
    my ($self, $log_file) = @_;
    return $self->_ant_call_comp("compile", undef, $log_file);
}

=pod

  $project->compile_tests([log_file])

Compiles the tests of the project version that is currently checked out.
If F<log_file> is provided, the compiler output is written to this file.

=cut

sub compile_tests {
    my ($self, $log_file) = @_;
    return $self->_ant_call_comp("compile.tests", undef, $log_file);
}

=pod

  $project->run_tests(result_file [, single_test])

Executes all developer-written tests in the checked-out program version. Failing tests are
written to C<result_file>.
If C<single_test> is provided, only this test method is run.
Format of C<single_test>: <classname>::<methodname>.

=cut

sub run_tests {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $out_file, $single_test) = @_;

    my $single_test_opt = "";
    if (defined $single_test) {
        $single_test =~ /([^:]+)::([^:]+)/ or die "Wrong format for single test!";
        $single_test_opt = "-Dtest.entry.class=$1 -Dtest.entry.method=$2";
    }

    return $self->_ant_call_comp("run.dev.tests", "-DOUTFILE=$out_file $single_test_opt");
}

=pod

  $project->run_relevant_tests(result_file)

Executes only developer-written tests that are relevant to the bug of the checked-out
program version. Failing tests are written to C<result_file>.

=cut

sub run_relevant_tests {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $out_file) = @_;

    return $self->_ant_call_comp("run.dev.tests", "-DOUTFILE=$out_file -Dd4j.relevant.tests.only=true");
}

=pod

  $project->compile_ext_tests(test_dir [, log_file])

Compiles an external test suite (e.g., a generated test suite) whose sources are located
in F<test_dir> against the project version that is currently checked out.
If F<log_file> is provided, the compiler output is written to this file.

=cut

sub compile_ext_tests {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $dir, $log_file) = @_;

    my $ret = $self->_ant_call("compile.gen.tests", "-Dd4j.test.dir=$dir", $log_file);
    if (!$ret && Utils::is_continuous_integration()) {
      opendir(my $dh, $dir) || die "Can't opendir $dir: $!";
      my @java_files = grep { /\.java$/ } readdir($dh);
      closedir($dh);
      foreach my $file (@java_files) {
        my $absfile = "$dir/$file";
        open(FILE, '<', "$absfile") or die "could not open $absfile";
        print(<FILE>);
        close(FILE);
      }
    }
    return $ret;
}

=pod

  $project->run_ext_tests(test_dir, test_include, result_file [, single_test])

Execute all of the tests in F<test_dir> that match the pattern C<test_include>.
Failing tests are written to F<result_file>.
If C<single_test> is provided, only this test method is executed.
Format of C<single_test>: <classname>::<methodname>.

=cut

sub run_ext_tests {
    @_ >= 4 or die $ARG_ERROR;
    my ($self, $dir, $include, $out_file, $single_test) = @_;

    my $single_test_opt = "";
    if (defined $single_test) {
        $single_test =~ /([^:]+)::([^:]+)/ or die "Wrong format for single test!";
        $single_test_opt = "-Dtest.entry.class=$1 -Dtest.entry.method=$2";
    }

    return $self->_ant_call("run.gen.tests", "-DOUTFILE=$out_file -Dd4j.test.dir=$dir -Dd4j.test.include=$include $single_test_opt");
}

=pod

  $project->fix_tests(vid)

Removes all broken tests in the checked-out program version. Which tests are broken and
removed is determined based on the provided version id C<vid>:
all tests listed in F<$PROJECTS_DIR/$PID/failing_tests/rev-id> are removed.

=cut

sub fix_tests {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    Utils::check_vid($vid);

    my $pid = $self->{pid};
    my $dir = $self->test_dir($vid);

    # TODO: Exclusively use version ids rather than revision ids
    # -> The bug-mining script that populates the database should deal with any
    # ID conversions.
    my $revision_id = $self->lookup($vid);
    my $failing_tests_file = "$PROJECTS_DIR/$pid/failing_tests/$revision_id";
    if (-e $failing_tests_file) {
        $self->exclude_tests_in_file($failing_tests_file, $dir);
    }

    # Remove flaky/dependent tests, if any
    my $dependent_test_file = "$PROJECTS_DIR/$pid/dependent_tests";
    if (-e $dependent_test_file) {
        $self->exclude_tests_in_file($dependent_test_file, $dir);
    }

    # Remove randomly failing tests, if any
    my $random_tests_file = "$PROJECTS_DIR/$pid/random_tests";
    if (-e $random_tests_file) {
        $self->exclude_tests_in_file($random_tests_file, $dir);
    }
}

=pod

=head2 Analysis related subroutines

=over 4

=item C<$project-E<gt>monitor_test(single_test, vid [, test_dir])>

Executes C<single_test>, monitors the class loader, and returns a reference to a
hash of list references, which store the loaded source and test classes.
Format of C<single_test>: <classname>::<methodname>.

This subroutine returns a reference to a hash with the keys C<src> and C<test>:

  {src} => [org.foo.Class1 org.bar.Class2]
  {test} => [org.foo.TestClass1 org.foo.TestClass2]

If the test execution fails, the returned reference is C<undef>.

A class is included in the result if it exists in the source or test directory
of the checked-out program version and if it was loaded during the test execution.

The location of the test sources can be provided with the optional parameter F<test_dir>.
The default is the test directory of the developer-written tests.

=cut

sub monitor_test {
    @_ >= 3 or die $ARG_ERROR;
    my ($self, $single_test, $vid, $test_dir) = @_;
    Utils::check_vid($vid);
    $single_test =~ /^([^:]+)(::([^:]+))?$/ or die "Wrong format for single test!";
    $test_dir = $test_dir // "$self->{prog_root}/" . $self->test_dir($vid);

    my $log_file = "$self->{prog_root}/classes.log";

    my $classes = {
        src  => [],
        test => []
    };

    if (! $self->_ant_call_comp("monitor.test", "-Dtest.entry=$single_test -Dtest.output=$log_file")) {
        return undef;
    }

    my $src = $self->_get_classes("$self->{prog_root}/" . $self->src_dir($vid));
    my $test= $self->_get_classes($test_dir);

    my @log = `cat $log_file`;
    foreach (@log) {
        chomp;
        # Try to find the correspondent .java file of a given loaded class X.
        #
        # X could be
        #  - A system class, e.g., java.io.ObjectInput, which is ignored by the following
        #    procedure as it does not belong to the project under test.
        #  - A "normal" class for which there is indeed a correspondent X.java file.
        #  - A "normal" class named with one or more $ symbols, e.g., com.google.gson.internal.$Gson$Types
        #    from Gson-{14,16,18}.
        #
        # First match corresponds to what a Java-8 JVM outputs; the second match
        # corresponds to what a Java-11 JVM outputs.
        s/\[Loaded (.*) from.*/$1/ or s/\S* (.*) source: .*/$1/;
        my $found = 0;
        if (defined $src->{$_}) {
            $found = 1;
            push(@{$classes->{src}}, $_);
            # Delete already loaded classes to avoid duplicates in the result
            delete($src->{$_});
        }
        if (defined $test->{$_}) {
            $found = 1;
            push(@{$classes->{test}}, $_);
            # Delete already loaded classes to avoid duplicates in the result
            delete($test->{$_});
        }
        if ($found == 0) {
            # The correspondent .java file of a given loaded class X has not been found.
            #
            # It might be that X is, for example, an inner class or anonymous class for which
            # there is no correspondent .java file, e.g., org.apache.commons.math3.util.MathArrays$OrderDirection
            # from Math-25.  Thus, try to find the correspondent .java file of X's parent class.
            #
            s/([^\$]*)(\$\S*)?/$1/;
            if (defined $src->{$_}) {
                push(@{$classes->{src}}, $_);
                # Delete already loaded classes to avoid duplicates in the result
                delete($src->{$_});
            }
            if (defined $test->{$_}) {
                push(@{$classes->{test}}, $_);
                # Delete already loaded classes to avoid duplicates in the result
                delete($test->{$_});
            }
        }
    }
    return $classes;
}

=pod

=item C<$project-E<gt>coverage_instrument(instrument_classes)>

Instruments classes listed in F<instrument_classes> for use with cobertura.

=cut

sub coverage_instrument {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $instrument_classes) = @_;
    my $work_dir = $self->{prog_root};

    -e $instrument_classes or die "Instrument classes file '$instrument_classes' does not exist!";
    open FH, $instrument_classes;
    my @classes = ();
    {
        $/ = "\n";
        @classes = <FH>;
    }
    close FH;

    die "No classes to instrument found!" if scalar @classes == 0;
    my @classes_and_inners = ();
    for (@classes) {
        s/\./\//g;
        chomp;
        push @classes_and_inners, "$_.class";
        push @classes_and_inners, "$_" . '\$' . "*.class";
    }

    # Write list of classes to instrument to properties file, which is imported
    # by the defects4j.build.xml file.
    my $list = join(",", @classes_and_inners);
    my $config = {$PROP_INSTRUMENT => $list};
    Utils::write_config_file("$work_dir/$PROP_FILE", $config);

    # Call ant to do the instrumentation
    return $self->_ant_call_comp("coverage.instrument");
}

=pod

=item C<$project-E<gt>coverage_report(source_dir)>

TODO

=cut

sub coverage_report {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $source_dir) = @_;
    return $self->_ant_call_comp("coverage.report", "-Dcoverage.src.dir=$source_dir");
}

=pod

=item C<$project-E<gt>mutate(instrument_classes, mut_ops)>

Mutates all classes listed in F<instrument_classes>, using all mutation operators
defined by the array reference C<mut_ops>, in the checked-out program version.
Returns the number of generated mutants on success, -1 otherwise.

=cut

sub mutate {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $instrument_classes, $mut_ops)  = @_;
    my $work_dir = $self->{prog_root};

    # Read all classes that should be mutated
    -e $instrument_classes or die "Classes file ($instrument_classes) does not exist!";
    open(IN, "<$instrument_classes") or die "Cannot read $instrument_classes";
    my @classes = ();
    while(<IN>) {
        s/\r?\n//;
        push(@classes, $_);
    }
    close(IN);
    # Update properties
    my $list_classes = join(",", @classes);
    my $list_mut_ops = join(",", @{$mut_ops});
    my $config = {$PROP_MUTATE => $list_classes, $PROP_MUT_OPS => $list_mut_ops};
    Utils::write_config_file("$work_dir/$PROP_FILE", $config);

    # Create mutation definitions (mml file)
    my $mml_src = "$self->{prog_root}/.mml/default.mml";
    my $mml_bin = "${mml_src}.bin";

    Mutation::create_mml($instrument_classes, $mml_src, $mut_ops);
    -e "$mml_bin" or die "Mml file does not exist: $mml_bin!";

    # Set environment variable MML, which is read by Major
    $ENV{MML} = "mml:$mml_bin";

    # Mutate and compile sources
    my $ret = $self->_call_major("mutate");

    delete($ENV{MML});

    if (! $ret) {
        return -1;
    }

    # Determine number of generated mutants
    open(MUT_LOG, "<$self->{prog_root}/mutants.log") or die "Cannot open mutants log: $!";
    my @lines = <MUT_LOG>;
    close(MUT_LOG);
    return scalar @lines;
}

=pod

=item C<$project-E<gt>mutation_analysis(log_file, relevant_tests [, exclude_file, single_test])>

Performs mutation analysis for the developer-written tests of the checked-out program
version.
The output of the mutation analysis process is redirected to F<log_file>, and the boolean
parameter C<relevant_tests> indicates whether only relevant test cases are executed. If
C<single_test> is specified, only that test is run.

B<Note that C<mutate> is not called implicitly>.

=cut

sub mutation_analysis {
    @_ >= 3 or die $ARG_ERROR;
    my ($self, $log_file, $relevant_tests, $exclude_file, $single_test) = @_;
    my $log = "-logfile $log_file";
    my $exclude = defined $exclude_file ? "-Dmajor.exclude=$exclude_file" : "";
    my $relevant = $relevant_tests ? "-Dd4j.relevant.tests.only=true" : "";

    my $single_test_opt = "";
    if (defined $single_test) {
        $single_test =~ /([^:]+)::([^:]+)/ or die "Wrong format for single test!";
        $single_test_opt = "-Dtest.entry.class=$1 -Dtest.entry.method=$2";
    }

    my $basedir = $self->{prog_root};

    return $self->_call_major("mutation.test",
                            "-Dmajor.kill.log=$basedir/$Mutation::KILL_FILE " .
                            "$relevant $log $exclude $single_test_opt");
}

=pod

=item C<$project-E<gt>mutation_analysis_ext(test_dir, test_include, log_file [, exclude_file, single_test])>

Performs mutation analysis for all tests in F<test_dir> that match the pattern
C<test_include>.
The output of the mutation analysis process is redirected to F<log_file>. If
C<single_test> is specified, only that test is run.

B<Note that C<mutate> is not called implicitly>.

=cut

sub mutation_analysis_ext {
    @_ >= 4 or die $ARG_ERROR;
    my ($self, $dir, $include, $log_file, $exclude_file, $single_test) = @_;
    my $log = "-logfile $log_file";
    my $exclude = defined $exclude_file ? "-Dmajor.exclude=$exclude_file" : "";

    my $basedir = $self->{prog_root};

    my $single_test_opt = "";
    if (defined $single_test) {
        $single_test =~ /([^:]+)::([^:]+)/ or die "Wrong format for single test!";
        $single_test_opt = "-Dtest.entry.class=$1 -Dtest.entry.method=$2";
    }

    return $self->_call_major("mutation.test",
                            "-Dd4j.test.dir=$dir -Dd4j.test.include=$include " .
                            "-Dmajor.kill.log=$basedir/$Mutation::KILL_FILE " .
                            "$log $exclude $single_test_opt");
}

=pod

=back

=cut

=pod

=head2 Vcs related subroutines

The following delegate subroutines are implemented merely for convenience.

=over 4

=item C<$project-E<gt>lookup(version_id)>

Delegate to the L<Vcs> backend.

=cut

sub lookup {
    my ($self, $vid) = @_;
    return $self->{_vcs}->lookup($vid);
}

=pod

=item C<$project-E<gt>lookup_vid(revision_id)>

Delegate to the L<Vcs> backend.

=cut

sub lookup_vid {
    my ($self, $rev_id) = @_;
    return $self->{_vcs}->lookup_vid($rev_id);
}

=pod

=item C<$project-E<gt>num_revision_pairs()>

Delegate to the L<Vcs> backend.

=cut

sub num_revision_pairs {
    @_ == 1 or die $ARG_ERROR;
    my ($self) = @_;
    return $self->{_vcs}->num_revision_pairs();
}

=pod

=item C<$project-E<gt>get_bug_ids()>

Delegate to the L<Vcs> backend.

=cut

sub get_bug_ids {
    @_ == 1 or die $ARG_ERROR;
    my ($self) = @_;
    return $self->{_vcs}->get_bug_ids();
}

=pod

=item C<$project-E<gt>contains_version_id(vid)>

Delegate to the L<Vcs> backend.

=cut

sub contains_version_id {
    my ($self, $vid) = @_;
    return $self->{_vcs}->contains_version_id($vid);
}

=pod

=item C<$project-E<gt>diff(revision_id_1, revision_id_2 [, path])>

Delegate to the L<Vcs> backend.

=cut

sub diff {
    my ($self, $rev1, $rev2, $path) = @_; shift;
    return $self->{_vcs}->diff(@_);
}

=pod

=item C<$project-E<gt>export_diff(revision_id_1, revision_id_2, out_file [, path])>

Delegate to the L<Vcs> backend.

=cut

sub export_diff {
    my ($self, $rev1, $rev2, $out_file, $path) = @_; shift;
    return $self->{_vcs}->export_diff(@_);
}

=pod

=item C<$project-E<gt>apply_patch(work_dir, patch_file)>

Delegate to the L<Vcs> backend.

=cut

sub apply_patch {
    my ($self, $work_dir, $patch_file) = @_; shift;
    return $self->{_vcs}->apply_patch(@_);
}

=pod

=back

=cut

# TODO: Document the purpose of this subroutine and indicate that it needs to be
# implemented in an inheriting module.
sub initialize_revision {
    my ($self, $rev_id, $vid) = @_;
}

##########################################################################################
# Helper subroutines
# TODO: Move to Util module

#
# Can we re-use an existing working directory?
#
sub _can_reuse_work_dir {
    @_ == 4 or die $ARG_ERROR;
    my ($new_pid, $new_vid, $old_pid, $old_vid) = @_;
    if ($new_pid ne $old_pid) {
        return 0;
    }

    my $tmp = Utils::check_vid($new_vid);
    my $new_bid = $tmp->{bid};
    $tmp = Utils::check_vid($old_vid);
    my $old_bid = $tmp->{bid};
    if ($new_bid ne $old_bid) {
        return 0;
    }

    return 1;
}

#
# Get all Java classes that exist in a given absolute path
#
sub _get_classes {
    my ($self, $path) = @_;
    my @list = `cd $path && find . -name "*.java"`;

    my $classes = {};
    foreach (@list) {
        chomp; s/\.\/(.+)\.java/$1/; s/\//\./g;
        $classes->{$_}="1";
    }
    return $classes;
}

#
# Helper function to call Ant
#
sub _ant_call {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $target, $option_str, $log_file, $ant_cmd) =  @_;
    $option_str = "" unless defined $option_str;
    $ant_cmd = "ant" unless defined $ant_cmd;

    my $verbose = ($DEBUG==1) ? " -v" : "";

    # Set up environment before running ant
    my $cmd = " cd $self->{prog_root}" .
              " && $ant_cmd" .
                $verbose .
                " -f $D4J_BUILD_FILE" .
                " -Dd4j.home=$BASE_DIR" .
                " -Dd4j.dir.projects=$PROJECTS_DIR" .
                " -Dbasedir=$self->{prog_root} ${option_str} $target 2>&1";
    my $log;
    my $ret = Utils::exec_cmd($cmd, "Running ant ($target)", \$log);

    if (defined $log_file) {
        open(OUT, ">>$log_file") or die "Cannot open log file: $!";
        print(OUT "$log");
        close(OUT);
    }
    return $ret;
}

#
# TODO: Remove after Defects4J downloads and initializes its own version of Ant
#       Currently, we rely on Major's version of Ant to be properly set up.
#
sub _ant_call_comp {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $target, $option_str, $log_file, $ant_cmd) =  @_;
    $option_str = ($option_str // "");
    $ant_cmd = "$MAJOR_ROOT/bin/ant" unless defined $ant_cmd;
    return $self->_ant_call($target, $option_str, $log_file, $ant_cmd);
}
sub _call_major {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $target, $option_str, $log_file, $ant_cmd) =  @_;
    $option_str = "-Dbuild.compiler=major.ant.MajorCompiler " . ($option_str // "");
    # Prepend path with Major's executables
    my $path = $ENV{PATH};
    $ENV{PATH}="$MAJOR_ROOT/bin:$ENV{PATH}";
    $ant_cmd = "$MAJOR_ROOT/bin/ant" unless defined $ant_cmd;
    my $ret = $self->_ant_call($target, $option_str, $log_file, $ant_cmd);
    # Reset path for downstream calls to ant
    $ENV{PATH} = $path;
    return($ret);
}

#
# Helper subroutine that returns a list of modified classes
#
sub _modified_classes {
    my ($self, $bid) = @_;
    my $project_dir = "$PROJECTS_DIR/$self->{pid}";
    open(IN, "<${project_dir}/modified_classes/${bid}.src") or warn "Cannot read modified classes, perhaps they have not been created yet?";
    my @classes = <IN>;
    close(IN);
    my $mod_classes = shift(@classes); chomp($mod_classes);
    defined $mod_classes or warn "Set of modified classes is empty!";
    foreach (@classes) {
        chomp;
        $mod_classes .= ",$_";
    }
    return $mod_classes;
}

#
# Helper subroutine that returns a list of relevant classes
#
sub _relevant_classes {
    my ($self, $bid) = @_;
    my $project_dir = "$PROJECTS_DIR/$self->{pid}";
    open(IN, "<${project_dir}/loaded_classes/${bid}.src")
        or warn "Cannot read loaded classes, perhaps they have not been created yet?";
    my @classes = <IN>;
    close(IN);
    my $rel_classes = shift(@classes); chomp($rel_classes);
    defined $rel_classes or warn "Set of loaded classes is empty!";
    foreach (@classes) {
        chomp;
        $rel_classes .= ",$_";
    }
    return $rel_classes;
}


#
# Write all version-specific properties to file
#
sub _write_props {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $vid, $is_bugmine) = @_;
    my $bid = Utils::check_vid($vid)->{bid};

    # will skip writing mod classes and trigger tests if we are bug mining because they are not defined yet
    my $mod_classes = "";
    my $rel_classes = "";
    my $trigger_tests = "";
    if(! $is_bugmine) {
        $mod_classes = $self->_modified_classes($bid);
        $rel_classes = $self->_relevant_classes($bid);

        my $project_dir = "$PROJECTS_DIR/$self->{pid}";
        my $triggers = Utils::get_failing_tests("${project_dir}/trigger_tests/${bid}");
        $trigger_tests = join(',', (@{$triggers->{classes}}, @{$triggers->{methods}}));
    }

    my $config = {
        $PROP_PID             => $self->{pid},
        $PROP_BID             => $bid,
        $PROP_DIR_SRC_CLASSES => $self->src_dir($vid),
        $PROP_DIR_SRC_CLASSES => $self->src_dir($vid),
        $PROP_DIR_SRC_TESTS   => $self->test_dir($vid),
        $PROP_CLASSES_MODIFIED=> $mod_classes,
        $PROP_CLASSES_RELEVANT=> $rel_classes,
        $PROP_TESTS_TRIGGER   => $trigger_tests,
    };
    Utils::write_config_file("$self->{prog_root}/$PROP_FILE", $config);
}

#
# Cache the directory-layout map from the project directory, if it exists.
#
sub _cache_layout_map {
    @_ == 1 or die $ARG_ERROR;
    my ($self) = @_;
    my $pid = $self->{pid};
    my $map_file = "$PROJECTS_DIR/$pid/$LAYOUT_FILE";
    return unless -e $map_file;

    open (IN, "<$map_file") or die "Cannot open directory map $map_file: $!";
    my $cache = {};
    while (<IN>) {
        chomp;
        /^([^,]+),([^,]+),(.+)$/ or die "Unexpected entry in layout map: $_";
        $cache->{$1} = {src=>$2, test=>$3};
    }
    close IN;
    $self->{_layout_cache} = $cache;
}

#
# Add a missing mapping to the directory-layout map
#
sub _add_to_layout_map {
    @_ == 4 or die $ARG_ERROR;
    my ($self, $rev_id, $src_dir, $test_dir) = @_;

    my $pid = $self->{pid};
    my $map_file = "$PROJECTS_DIR/$pid/$LAYOUT_FILE";
    Utils::append_to_file_unless_matches($map_file, "${rev_id},${src_dir},${test_dir}\n", qr/^${rev_id}/);
}

#
# Determines directory layout for a given revision. It returns the cached
# layout, if it exists, or invokes determine_layout (has to be defined in each
# Project module) to determine and cache the layout.
#
sub _determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $rev_id) = @_;
    unless (defined $self->{_layout_cache}->{$rev_id}) {
        $self->{_layout_cache}->{$rev_id} = $self->determine_layout($rev_id);
        $self->_add_to_layout_map($rev_id,
            $self->{_layout_cache}->{$rev_id}->{src},
            $self->{_layout_cache}->{$rev_id}->{test}
        );
    }
    return $self->{_layout_cache}->{$rev_id};
}

1;
