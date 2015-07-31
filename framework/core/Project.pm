#-------------------------------------------------------------------------------
# Copyright (c) 2014-2015 René Just, Darioush Jalali, and Defects4J contributors.
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

Project.pm -- Provides a general interface and abstraction for all projects.
An instance of Project represents one of the analyzed open source projects.

=head1 SYNOPSIS

=head2 In embedding script:

use Project;

my $pid=$ARGV[0];

my $project = Project::create_project($pid);

$project->print_info();

=head2 Create new Project submodule:

package Project::MyProject;

use Constants;

use Vcs::Git; # or Svn, etc.

our @ISA = qw(Project);

my $PID = "project-id";

sub new {
    my $class = shift;
    my $name = "my-project-name";
    my $src = "src_dir";
    my $test = "test_dir";
    my $build_file = "path-to-build-file";
    my $vcs = Vcs::Git->new($PID,
                            "file://$REPO_DIR/$name.git",
                            "$SCRIPT_DIR/projects/$name/commit-db");
                            # Add post checkout hook argument
                            # if necessary -- see Vcs.pm for details

    return $class->SUPER::new($name, $vcs, $src, $test, $build_file);
}

The C<$build_file> argument is optional. If omitted, the default file name is
F<$SCRIPT_DIR/projects/${name}/${name}.build.xml">.

=head1 DESCRIPTION

This module provides a general abstraction for attributes and methods of a
concrete project. A specific project object can be created by
C<create_project(project_id)>. The C<project_id> has to match the subpackage
name of the corresponding project.

=head2 Available project_ids:

=over 4

=item B<Chart>  JFreeChart (uses Vcs::Svn as Vcs backend)

=item B<Math>  Commons math (uses Vcs::Git as Vcs backend)

=item B<Lang>  Commons lang (uses Vcs::Git as Vcs backend)

=item B<Time>  Joda-time (uses Vcs::Git as Vcs backend)

=item B<Closure>  Closure compiler (uses Vcs::Git as Vcs backend)

=back

Every project has to provide an Apache Ant F<build.xml> build file.

=head2 Mandatory targets in project's build file

=over 4

=item B<compile>

=item B<compile.tests>

=item B<mutate>

=item B<test>

=back

=head2 Optional targets in project's build file

=over 4

=item B<compile.gen.tests>

=item B<run.gen.tests>

=back

=cut
package Project;

use warnings;
use strict;
use Constants;
use Utils;

=pod

=head2 Create an object for a specific project:

=over 4

=item B<Project::create_project(project_id)>

Dynamically load the required module, instantiate the project, and return the
reference to it.

=back

=cut
sub create_project {
    @_ == 1 or die "$ARG_ERROR Use: create_project(project_id)";
    my $pid = shift;
    my $module = __PACKAGE__ . "/$pid.pm";
    my $class  = __PACKAGE__ . "::$pid";

    eval { require $module };
    die "Invalid project_id: $pid\n$@" if $@;

    return $class->new();
}

=pod

=head2 Object attributes for an instance of Project:

=over 4

=item B<prog_name>

The program name for the project.

=item B<prog_root>

The root (working) directory for the project. The default C<prog_root> for a
project is F</tmp/"project_id"_"current-time">.

=back

=cut
sub new {
    @_ >= 6 or die $ARG_ERROR;
    my ($class, $pid, $prog, $vcs, $src, $test, $build_file) = @_;
    my $prog_root = $ENV{PROG_ROOT}; $prog_root = "/tmp/${pid}_".time unless defined $prog_root;
    $build_file = "$SCRIPT_DIR/projects/$pid/$pid.build.xml" unless defined $build_file;

    my $self = {
        pid        => $pid,
        prog_name  => $prog,
        prog_root  => $prog_root,
        _vcs       => $vcs,
        _src_dir   => $src,
        _test_dir  => $test,
        _build_file =>$build_file,
    };
    bless $self, $class;
    return $self;
}

=pod

=head2 General object methods:

=over 4

=item B<print_info> C<print_info()>

Print all general and project-specific properties to STDOUT

=cut
sub print_info {
    my $self = shift;
    print "Summary of configuration for Project: $self->{pid}\n";
    print "-"x80 . "\n";
    printf ("%14s: %s\n", "Script dir", $SCRIPT_DIR);
    printf ("%14s: %s\n", "Base dir", $BASE_DIR);
    printf ("%14s: %s\n", "Major root", $MAJOR_ROOT);
    printf ("%14s: %s\n", "Repo dir", $REPO_DIR);
    print "-"x80 . "\n";
    printf ("%14s: %s\n", "Project ID", $self->{pid});
    printf ("%14s: %s\n", "Program", $self->{prog_name});
    printf ("%14s: %s\n", "Build file", $self->{_build_file});
    print "-"x80 . "\n";
    printf ("%14s: %s\n", "Vcs", ref $self->{_vcs});
    printf ("%14s: %s\n", "Repository", $self->{_vcs}->{repo});
    printf ("%14s: %s\n", "Commit db", $self->{_vcs}->{commit_db});
    my @ids = $self->get_version_ids();
    printf ("%14s: %s\n", "Number of bugs", scalar(@ids));
    print "-"x80 . "\n";
}

=pod

=item B<src_dir> C<src_dir(vid)>

Returns the relative path to the directory of the source files for a given
version id C<vid>. The returned path is relative to the working directory.

=cut
sub src_dir {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    return $self->{_src_dir};
}

=pod

=item B<test_dir> C<test_dir(vid)>

Returns the relative path to the directory of the junit test files for a given
version id C<vid>. The returned path is relative to the working directory.

=back

=cut
sub test_dir {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    return $self->{_test_dir};
}

=pod

=head2 Build system related methods:

=over 4

=item B<sanity_check> C<sanity_check()>

Check whether the project is correctly configured

=cut
sub sanity_check {
    my $self = shift;
    return $self->_ant_call("sanity.check");
}
=pod

=item B<compile> C<compile()>

Compile the project version that is currently checked out

=cut
sub compile {
    my $self = shift;
    return $self->_ant_call("compile");
}

=pod

=item B<compile_tests> C<compile_tests()>

Compile tests of the project version that is currently checked out

=cut
sub compile_tests {
    my $self = shift;
    return $self->_ant_call("compile.tests");
}

=pod

=item B<compile_ext_tests> C<compile_ext_tests(test_dir)>

Compile an external test suite whose sources are located in C<test_dir>
against the project version that is currently checked out.

=cut
sub compile_ext_tests {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $dir, $log_file) = @_;

    return $self->_ant_call("compile.gen.tests", "-Dbug-db.test.dir=$dir", $log_file);
}

=pod

=item B<run_ext_tests> C<run_ext_tests(test_dir, test_include, result_file [, single_test])>

Run all of the tests in C<test_dir> that match the pattern C<test_include>.
If C<single_test> is provided, only this test method is run.
The string C<single_test> has to have the format: B<classname::methodname>.
Failing tests are written to C<result_file>

=cut
sub run_ext_tests {
    @_ >= 4 or die $ARG_ERROR;
    my ($self, $dir, $include, $out_file, $single_test) = @_;

    my $single_test_opt = "";
    if (defined $single_test) {
        $single_test =~ /([^:]+)::([^:]+)/ or die "Wrong format for single test!";
        $single_test_opt = "-Dtest.entry.class=$1 -Dtest.entry.method=$2";
    }

    return $self->_ant_call("run.gen.tests", "-Dformatter_cp=$LIB_DIR/formatter.jar -DOUTFILE=$out_file -Dbug-db.test.dir=$dir -Dtest.include=$include $single_test_opt");
}

=pod

=item B<fix_tests> C<fix_tests(vid)>

Fix all broken tests in the checked-out version. Broken tests are determined
based on the provided version id C<vid>.

All tests listed in F<$SCRIPT_DIR/projects/$pid/failing_tests/file> are removed:

=over 8

=item All test methods listed in F<file> are removed from the source code

=item All test classes listed in F<file> are added to the exclude list in
F<"work_dir"/$PROP_FILE>

=back

=cut
sub fix_tests {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    Utils::check_vid($vid);

    my $pid = $self->{pid};
    my $dir = $self->test_dir($vid);

    # TODO: Exclusively use version ids rather than revision ids
    my $revision_id = $self->lookup($vid);
    my $file = "$SCRIPT_DIR/projects/$pid/failing_tests/$revision_id";

    if (-e $file) {
        $self->exclude_tests_in_file($file, $dir);
    }

    # This code added to exclude test dependencies
    my $dependent_test_file = "$SCRIPT_DIR/projects/$pid/dependent_tests";
    if (-e $dependent_test_file) {
        $self->exclude_tests_in_file($dependent_test_file, $dir);
    }
}

=item B<exclude_tests_in_file> C<exclude_tests_in_file(file, tests_dir)>

Excludes all broken tests in the checked out version. Broken tests are
determined based on the provided C<file>. The test sources must exist in the
C<tests_dir> directory, which is relative to C<$self->{prog_root}>.

=over 8

=item All test methods listed in F<file> are removed from the source code

=item All test classes listed in F<file> are added to the exclude list in
F<"work_dir"/$PROP_FILE>

=back

=cut
sub exclude_tests_in_file {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $file, $tests_dir) = @_;
    my $work_dir = $self->{prog_root};

    # Remove broken test methods
    system("$UTIL_DIR/rm_broken_tests.pl $file $work_dir/$tests_dir") == 0 or die;

    # Check whether broken test classes should be excluded
    my $failed = Utils::get_failing_tests($file);
    my @classes= @{$failed->{classes}};

    return if scalar @classes == 0;
# TODO: Some projects may define tests to include/exclude on the classes
# directory -> .java won't work in that case.
    for (@classes) {
        s/\./\//g; s/(.*)/$1.java/;
    }
    # Write list of test classes to exclude to properties file, which is
    # imported by the defects4j.build.xml file.
    my $list = join(", ", @classes);
    my $config = {$PROP_EXCLUDE => $list};
    Utils::write_config_file("$work_dir/$PROP_FILE", $config);
}

=pod

=item B<coverage_instrument> C<coverage_instrument(modified_classes_file)>

Instruments classes listed in the file for use with cobertura.

=cut
sub coverage_instrument {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $modified_classes_file) = @_;
    my $work_dir = $self->{prog_root};

    -e $modified_classes_file or die "modified classes file '$modified_classes_file' does not exist";
    open FH, $modified_classes_file;
    my @classes = ();
    {
        $/ = "\n";
        @classes = <FH>;
    }
    close FH;

    die "no modified classes" if scalar @classes == 0;
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
    $self->_ant_call("coverage.instrument");
}

=pod

=item B<run_evosuite> C<run_evosuite(target_criterion, target_time, target_class, assertion_timeout, config_file [, log_file])>

Run EvoSuite on the project version that is currently checked out.

=cut
sub run_evosuite {
    @_ >= 6 or die $ARG_ERROR;
    my ($self, $criterion, $time, $class, $timeout, $config_file, $log) = @_;

    my $cp_file = "$self->{prog_root}/project.cp";
    $self->_ant_call("export.cp.compile", "-Dfile.export=$cp_file") == 0 or die "Cannot determine project classpath";
    my $cp = `cat $cp_file`;

    # Read additional evosuite configuration
    my $config = "";
    open(IN, "<$config_file") or die "Cannot read evosuite config file: $config_file";
    while(<IN>) {
        # Skip comments
        next if /^\s*#/;
        chomp;
        $config = "$config $_";
    }
    close(IN);

    my $cmd = "java -cp $SCRIPT_DIR/projects/lib/evosuite.jar org.evosuite.EvoSuite " .
                "-class $class " .
                "-projectCP $cp " .
                "-Dtest_dir=evosuite-$criterion " .
                "-criterion $criterion " .
                "-Dsearch_budget=$time " .
                "-Dassertion_timeout=$timeout " .
                "-Djunit_suffix=EvoSuite_$criterion " .
                "-Dshow_progress=false " .
                "$config";

    print(STDERR "Running EvoSuite ($criterion) using config $config_file ... ");
    my $output = `cd $self->{prog_root}; $cmd 2>&1`;
    my $ret = $?;

    if ($ret==0) {
        print(STDERR "OK\n");
    } else {
        print(STDERR "FAIL\n$output");
    }

    if (defined $log) {
        open(OUT, ">>$log") or die "Cannot open log file: $!";
        print(OUT "$output");
        close(OUT)
    }

    return $ret;
}

# TODO: Provide separate module for test generation
# TODO: Extract common (config parsing etc.) code in run_evosuite and run_randoop
=pod

=item B<run_randoop> C<run_randoop(target_classes, timeout, seed, config_file [, log_file])>

Run Randoop on the project version that is currently checked out.

=cut
sub run_randoop {
    @_ >= 5 or die $ARG_ERROR;
    my ($self, $target_classes, $timeout, $seed, $config_file, $log) = @_;

    my $cp_file = "$self->{prog_root}/project.cp";
    $self->_ant_call("export.cp.compile", "-Dfile.export=$cp_file") == 0 or die "Cannot determine project classpath";
    my $cp = `cat $cp_file`;

    # Read additional randoop configuration
    my $config = "";
    open(IN, "<$config_file") or die "Cannot read Randoop config file: $config_file";
    while(<IN>) {
        # Skip comments
        next if /^\s*#/;
        chomp;
        $config = "$config $_";
    }
    close(IN);

    my $cmd = "java -ea -classpath $SCRIPT_DIR/projects/lib/randoop.jar:$cp randoop.main.Main gentests " .
              "$target_classes " .
              "--junit-output-dir=randoop " .
              "--timelimit=$timeout " .
              "--randomseed=$seed " .
              "$config";

    print(STDERR "Running Randoop using config $config_file ... ");
    my $output = `cd $self->{prog_root}; $cmd 2>&1`;
    my $ret = $?;

    if ($ret==0) {
        print(STDERR "OK\n");
    } else {
        print(STDERR "FAIL\n$output");
    }

    if (defined $log) {
        open(OUT, ">>$log") or die "Cannot open log file: $!";
        print(OUT "$output");
        close(OUT)
    }

    return $ret;
}


=pod

=item B<mutate> C<mutate()>

Mutate the project revision that is currently checked out.
Returns the number of generated mutants on success, -1 otherwise.

=cut
sub mutate {
    my $self = shift;
    return -1 if ($self->_ant_call("mutate") != 0);

    # Determine number of generated mutants
    open(MUT_LOG, "<$self->{prog_root}/mutants.log") or die "Cannot open mutants log: $!";
    my @lines = <MUT_LOG>;
    close(MUT_LOG);
    return scalar @lines;
}

=pod

=item B<run_tests> C<run_tests(result_file [, single_test])>

Run all of the tests in the project, unless C<single_test> is provided.
If C<single_test> is provided, only this test method is run.
The string C<single_test> has to have the format: B<classname::methodname>.
Failing tests are written to C<result_file>

=cut
sub run_tests {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $out_file, $single_test) = @_;

    my $single_test_opt = "";
    if (defined $single_test) {
        $single_test =~ /([^:]+)::([^:]+)/ or die "Wrong format for single test!";
        $single_test_opt = "-Dtest.entry.class=$1 -Dtest.entry.method=$2";
    }

    return $self->_ant_call("test", "-Dformatter_cp=$LIB_DIR/formatter.jar -DOUTFILE=$out_file $single_test_opt");
}

=pod

=item B<coverage> C<coverage()>

Run tests of the project version that is currently checked out with cobertura

=cut
sub coverage {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $out_file, $single_test) = @_;

    my $single_test_opt = "";
    if (defined $single_test) {
        $single_test =~ /([^:]+)::([^:]+)/ or die "Wrong format for single test!";
        $single_test_opt = "-Dtest.entry.class=$1 -Dtest.entry.method=$2";
    }

    return $self->_ant_call("coverage", "-Dformatter_cp=$LIB_DIR/formatter.jar -DOUTFILE=$out_file $single_test_opt");
}

sub coverage_report {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $source_dir) = @_;
    return $self->_ant_call("coverage.report", "-Dcoverage.src.dir=$source_dir");
}


=pod

=item B<mutation_analysis> C<mutation_analysis([log_file])>

Run mutation analysis for all tests in the project. If the optional argument
C<log_file> is provided then the output of the mutation analysis process is
redirected to this file. B<Note that C<mutate> is not called implicitly>

=cut
sub mutation_analysis {
    @_ >= 1 or die $ARG_ERROR;
    my ($self, $log_file, $single_test) = @_;
    my $log = "";
    $log = "-logfile $log_file" if defined $log_file;

    my $single_test_opt = "";
    if (defined $single_test) {
        $single_test =~ /([^:]+)::([^:]+)/ or die "Wrong format for single test!";
        $single_test_opt = "-Dtest.entry.class=$1 -Dtest.entry.method=$2";
    }

    my $basedir = $self->{prog_root};

    return $self->_ant_call("mutation.test",
                            "-Dmajor.exclude=$basedir/exclude.txt " .
                            "-Dmajor.kill.log=$basedir/kill.csv " .
                            "$log $single_test_opt");
}

=pod

=item B<mutation_analysis_ext> C<mutation_analysis_ext(test_dir, test_include [, log_file])>

Run mutation analysis for all tests in C<test_dir> that match the pattern
C<test_include>. If the optional argument C<log_file> is provided then the
output of the mutation analysis process is redirected to this file.
B<Note that C<mutate> is not called implicitly>

=cut
sub mutation_analysis_ext {
    @_ >= 3 or die $ARG_ERROR;
    my ($self, $dir, $include, $log_file) = @_;
    my $log = "";
    $log = "-logfile $log_file" if defined $log_file;

    my $basedir = $self->{prog_root};

    return $self->_ant_call("mutation.test",
                            "-Dbug-db.test.dir=$dir -Dtest.include=$include " .
                            "-Dmajor.exclude=$basedir/exclude.txt " .
                            "-Dmajor.kill.log=$basedir/kill.csv " .
                            "$log");
}

=pod

=item B<monitor_test> C<monitor_test(single_test, vid)>

Runs C<single_test>, monitors the class loader, and returns a reference to a
hash of list references, which store the loaded src and test classes.

The returned reference is a reference to a hash that looks like:

{src} => [org.foo.Class1 org.bar.Class2]

{test} => [org.foo.TestClass1 org.foo.TestClass2]

The string C<single_test> has to have the format: B<classname::methodname>.
If the test execution fails, the returned reference is C<undef>.

A class is included in the result if it exists in the source or test directory
of the checked-out verion and if it was loaded during the test execution.

=back

=cut
sub monitor_test {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $single_test, $vid) = @_;
    Utils::check_vid($vid);
    $single_test =~ /^([^:]+)(::([^:]+))?$/ or die "Wrong format for single test!";

    my $log_file = "$self->{prog_root}/classes.log";

    my $classes = {
        src  => [],
        test => []
    };

    my $ret = $self->_ant_call("monitor.test", "-Dformatter_cp=$LIB_DIR/formatter.jar -Dtest.entry=$single_test -Dtest.output=$log_file");
    $ret == 0 or return undef;

    my $src = $self->_get_classes($self->src_dir($vid));
    my $test= $self->_get_classes($self->test_dir($vid));

    my @log = `cat $log_file`;
    foreach (@log) {
        chomp;
        s/\[Loaded ([^\$]*)(\$\S*)? from.*/$1/;
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
    return $classes;
}

# Get all classes for a given path in the working directory
sub _get_classes {
    my ($self, $path) = @_;
    my $dir = $self->{prog_root};
    my @list = `cd $dir/$path; find . -name "*.java"`;

    my $classes = {};
    foreach (@list) {
        chomp; s/\.\/(.+)\.java/$1/; s/\//\./g;
        $classes->{$_}="1";
    }
    return $classes;
}

# Helper function to call Ant
sub _ant_call {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $target, $option_str, $log_file) =  @_;
    $option_str = "" unless defined $option_str;
    my $file = $self->{_build_file};
    # TODO: Check also whether target is provided by the build file
    -f $file or die "Build file does not exist: $file";

    print(STDERR "Running ant ($target) ... ");
    my $log = `cd $self->{prog_root}; ant -f $self->{_build_file} -Dscript.dir=$SCRIPT_DIR -Dbasedir=$self->{prog_root} ${option_str} $target 2>&1`;
    my $ret = $?;

    if (defined $log_file) {
        open(OUT, ">>$log_file") or die "Cannot open log file: $!";
        print(OUT "$log");
        close(OUT);
    }
    if ($ret==0) {
        print(STDERR "OK\n");
        # Print log if debugging is enabled
        print(STDERR $log) if $DEBUG;
    } else {
        print(STDERR "FAIL\n");
        # Always print log if ant fails
        print(STDERR $log);
    }
    return $ret;
}

# Write all version-specific properties to file
sub _write_props {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $vid, $work_dir) = @_;
    Utils::check_vid($vid);
    $vid =~ /^(\d+)[bf]$/ or die "Unexpected version id: $vid!";
    my $bid = $1;

    # TODO: Provide a helper subroutine that returns a list of modified classes
    my $project_dir = "$SCRIPT_DIR/projects/$self->{pid}";
    open(IN, "<${project_dir}/modified_classes/${bid}.src") or die "Cannot read modified classes";
    my @classes = <IN>;
    close(IN);
    my $mod_classes = shift(@classes); chomp($mod_classes);
    defined $mod_classes or die "Set of modified classes is empty!";
    foreach (@classes) {
        chomp;
        $mod_classes .= ",$_";
    }

    my $triggers = Utils::get_failing_tests("${project_dir}/trigger_tests/${bid}");
    my $trigger_tests = join(',', (@{$triggers->{classes}}, @{$triggers->{methods}}));

    my $config = {
        $PROP_DIR_SRC_CLASSES => $self->src_dir($vid),
        $PROP_DIR_SRC_TESTS   => $self->test_dir($vid),
        $PROP_CLASSES_MODIFIED=> $mod_classes,
        $PROP_TESTS_TRIGGER   => $trigger_tests,
    };
    Utils::write_config_file("$work_dir/$PROP_FILE", $config);
}

=pod

=head2 Version control system (Vcs) related object methods:

=over 4

=item B<lookup> C<lookup(version_id)>

Delegate to the lookup method of the vcs backend -- see Vcs.pm

=cut
sub lookup {
    my ($self, $vid) = @_;
    return $self->{_vcs}->lookup($vid);
}

=pod

=item B<num_revision_pairs> C<num_revision_pairs()>

Delegate to the C<num_revision_pairs> method of the vcs backend -- see Vcs.pm

=cut
sub num_revision_pairs {
    my $self = shift;
    return $self->{_vcs}->num_revision_pairs();
}


=pod

=item B<get_version_ids> C<get_version_ids()>

Delegate to the get_version_id method of the vcs backend -- see Vcs.pm

=cut
sub get_version_ids {
    my $self = shift;
    return $self->{_vcs}->get_version_ids();
}
=pod

=item B<checkout_id> C<checkout_id(vid [, work_dir])>

Delegate to the checkout_id method of the vcs backend -- see Vcs.pm

C<work_dir> is optional, the default is F<"prog_root">.

=cut
sub checkout_id {
    my ($self, $vid, $work_dir) = @_; shift;
    Utils::check_vid($vid);
    unless (defined $work_dir) {
        $work_dir = $self->{prog_root} ;
        push(@_, $work_dir);
    }
    my $ret = $self->{_vcs}->checkout_id(@_);

    # Return if checkout failed
    if ($ret != 0) {
        return $ret;
    }

    # Write version-specific properties
    $self->_write_props($vid, $work_dir);

    return $ret;
}


=pod

=item B<diff> C<diff(revision_id_1, revision_id_2 [, path])>

Delegate to the diff method of the vcs backend -- see Vcs.pm

=cut
sub diff {
    my ($self, $rev1, $rev2, $path) = @_; shift;
    return $self->{_vcs}->diff(@_);
}
=pod

=item B<export_diff> C<export_diff(revision_id_1, revision_id_2, out_file [, path])>

Delegate to the export_diff method of the vcs backend -- see Vcs.pm

=cut
sub export_diff {
    my ($self, $rev1, $rev2, $out_file, $path) = @_; shift;
    return $self->{_vcs}->export_diff(@_);
}

=pod

=item B<apply_patch> C<apply_patch(work_dir, patch_file [, path])>

Delegate to the apply_patch method of the vcs backend -- see Vcs.pm

=back

=cut
sub apply_patch {
    my ($self, $work_dir, $patch_file, $path) = @_; shift;
    return $self->{_vcs}->apply_patch(@_);
}

1;
=pod

=head1 SEE ALSO

F<Vcs.pm> F<project_info.pl> F<Constants.pm>

=cut

