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

Project::JxPath.pm -- L<Project> submodule for commons-jxpath.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
commons-jxpath project.

=cut
package Project::JxPath;

use strict;
use warnings;

use Constants;
use Vcs::Git;
use File::Copy;

our @ISA = qw(Project);
my $PID  = "JxPath";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "commons-jxpath";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs);
}

##
## Determines the directory layout for sources and tests
##
sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $rev_id) = @_;
    my $work_dir = $self->{prog_root};

    # Only two sets of layouts in this case
    my $result;
    if (-e "$work_dir/src/main"){
      $result = {src=>"src/main/java", test=>"src/test/java"};
    }
    if (-e "$work_dir/src/java"){
      $result = {src=>"src/java", test=>"src/test"};
    }
    die "Unknown layout for revision: ${rev_id}" unless defined $result;
    return $result;
}

#
# Post-checkout tasks include, for instance, providing cached build files,
# fixing compilation errors, etc.
#
sub _post_checkout {
    my ($self, $rev_id, $work_dir) = @_;

    my $bid = Utils::get_bid($work_dir);

    # Fix compilation errors if necessary.
    # Run this as the first step to ensure that patches are applicable to
    # unmodified source files.
    my $compile_errors = "$PROJECTS_DIR/$self->{pid}/compile-errors/";
    opendir(DIR, $compile_errors) or die "Could not find compile-errors directory.";
    my @entries = readdir(DIR);
    closedir(DIR);
    foreach my $file (@entries) {
        if ($file =~ /-(\d+)-(\d+).diff/) {
            if ($bid >= $1 && $bid <= $2) {
                $self->apply_patch($work_dir, "$compile_errors/$file")
                        or die("Couldn't apply patch ($file): $!");
            }
        }
    }

    # Check whether ant build file exists
    unless (-e "$work_dir/build.xml") {
        my $build_files_dir = "$PROJECTS_DIR/$PID/build_files/$rev_id";
        if (-d "$build_files_dir") {
            Utils::exec_cmd("cp -r $build_files_dir/* $work_dir", "Copy generated Ant build file") or die;
        }
    }

    # Copy in a missing dependency
    my $project_dir = "$PROJECTS_DIR/$self->{pid}";
    mkdir $work_dir."/target";
    mkdir $work_dir."/target/lib";
    copy($project_dir."/lib/mockrunner-0.4.1.jar", $work_dir."/target/lib/mockrunner-0.4.1.jar") or die "Copy failed: $!";

    # Set source and target version in javac targets.
    my $jvm_version="1.6";

    # JxPath uses "compile-tests" instead of "compile.test" as a target name. 
    # Replace all instances of "compile-tests" with "compile.test".
    # They also use "build.classpath" instead of "compile.classpath".
    # This also replaces several dead links in the build file

    if (-e "$work_dir/build.xml"){
        rename("$work_dir/build.xml", "$work_dir/build.xml".'.bak');
        open(IN, '<'."$work_dir/build.xml".'.bak') or die $!;
        open(OUT, '>'."$work_dir/build.xml") or die $!;
        while(<IN>) {
            $_ =~ s/javac destdir="\$\{classesdir\}" deprecation="true"/javac destdir="\$\{classesdir\}" target="${jvm_version}" source="${jvm_version}" deprecation="true"/g;
            $_ =~ s/javac destdir="\$\{testclassesdir\}" deprecation="true"/javac destdir="\$\{testclassesdir\}" target="${jvm_version}" source="${jvm_version}" deprecation="true"/g;
            $_ =~ s/compile-tests/compile\.tests/g;
            $_ =~ s/classesdir/classes\.dir/g;
            $_ =~ s/testclasses\.dir/test\.classes\.dir/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven2\/com\/mockrunner\/mockrunner-jdk1.3-j2ee1.3\/0\.4\/mockrunner-jdk1\.3-j2ee1\.3-0\.4\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/mockrunner-0\.4\.1\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/servletapi\/jars\/servletapi-2\.4\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/servletapi\/servletapi\/2\.4\/servletapi-2\.4\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/jspapi\/jars\/jsp-api-2\.0\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/jspapi\/jsp-api\/2\.0\/jsp-api-2\.0\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/commons-beanutils\/jars\/commons-beanutils-1\.7\.0\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/commons-beanutils\/commons-beanutils\/1\.7\.0\/commons-beanutils-1\.7\.0\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/commons-logging\/jars\/commons-logging-1\.1\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/commons-logging\/commons-logging\/1\.1\/commons-logging-1\.1\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/junit\/jars\/junit-3\.8\.2\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/junit\/junit\/3\.8\.2\/junit-3\.8\.2\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/ant\/jars\/ant-optional-1\.5\.1\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/ant\/ant-optional\/1\.5\.1\/ant-optional-1\.5\.1\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/ant\/jars\/ant-1\.5\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/ant\/ant\/1\.5\/ant-1\.5\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/ant\/jars\/ant-optional-1\.5\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/ant\/ant-optional\/1\.5\/ant-optional-1\.5\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/xerces\/jars\/xerces-1\.2\.3\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/xerces\/xerces\/1\.2\.3\/xerces-1\.2\.3\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/xerces\/jars\/xerces-2\.4\.0\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/xerces\/xerces\/2\.4\.0\/xerces-2\.4\.0\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/servletapi\/jars\/servletapi-2\.2\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/servletapi\/servletapi\/2\.2\/servletapi-2\.2\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/junit\/jars\/junit-3\.8\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/junit\/junit\/3\.8\/junit-3\.8\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/xml-apis\/jars\/xml-apis-2\.0\.2\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/xml-apis\/xml-apis\/2\.0\.2\/xml-apis-2\.0\.2\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/jdom\/jars\/jdom-1\.0\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/jdom\/jdom\/1\.0\/jdom-1\.0\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/commons-beanutils\/jars\/commons-beanutils-1\.4\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/commons-beanutils\/commons-beanutils\/1\.4\/commons-beanutils-1\.4\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/commons-logging\/jars\/commons-logging-1\.0\.4\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/commons-logging\/commons-logging\/1\.0\.4\/commons-logging-1\.0\.4\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/commons-collections\/jars\/commons-collections-2\.0\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/commons-collections\/commons-collections\/2\.0\/commons-collections-2\.0\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/junit\/jars\/junit-3\.8\.1\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/junit\/junit\/3\.8\.1\/junit-3\.8\.1\.jar/g;
            print OUT $_;
        }
        close(IN);
        close(OUT);
    }

    if (-e "$work_dir/maven-build.xml"){
        rename("$work_dir/maven-build.xml", "$work_dir/maven-build.xml".'.bak');
        open(IN, '<'."$work_dir/maven-build.xml".'.bak') or die $!;
        open(OUT, '>'."$work_dir/maven-build.xml") or die $!;
        while(<IN>) {
            $_ =~ s/compile-tests/compile\.tests/g;
            $_ =~ s/classesdir/classes\.dir/g;
            $_ =~ s/testclasses\.dir/test\.classes\.dir/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven2\/com\/mockrunner\/mockrunner-jdk1.3-j2ee1.3\/0\.4\/mockrunner-jdk1\.3-j2ee1\.3-0\.4\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/mockrunner-0\.4\.1\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/servletapi\/jars\/servletapi-2\.4\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/servletapi\/servletapi\/2\.4\/servletapi-2\.4\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/jspapi\/jars\/jsp-api-2\.0\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/jspapi\/jsp-api\/2\.0\/jsp-api-2\.0\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/commons-beanutils\/jars\/commons-beanutils-1\.7\.0\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/commons-beanutils\/commons-beanutils\/1\.7\.0\/commons-beanutils-1\.7\.0\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/commons-logging\/jars\/commons-logging-1\.1\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/commons-logging\/commons-logging\/1\.1\/commons-logging-1\.1\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/junit\/jars\/junit-3\.8\.2\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/junit\/junit\/3\.8\.2\/junit-3\.8\.2\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/ant\/jars\/ant-optional-1\.5\.1\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/ant\/ant-optional\/1\.5\.1\/ant-optional-1\.5\.1\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/ant\/jars\/ant-1\.5\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/ant\/ant\/1\.5\/ant-1\.5\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/ant\/jars\/ant-optional-1\.5\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/ant\/ant-optional\/1\.5\/ant-optional-1\.5\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/xerces\/jars\/xerces-1\.2\.3\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/xerces\/xerces\/1\.2\.3\/xerces-1\.2\.3\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/xerces\/jars\/xerces-2\.4\.0\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/xerces\/xerces\/2\.4\.0\/xerces-2\.4\.0\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/servletapi\/jars\/servletapi-2\.2\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/servletapi\/servletapi\/2\.2\/servletapi-2\.2\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/junit\/jars\/junit-3\.8\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/junit\/junit\/3\.8\/junit-3\.8\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/xml-apis\/jars\/xml-apis-2\.0\.2\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/xml-apis\/xml-apis\/2\.0\.2\/xml-apis-2\.0\.2\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/jdom\/jars\/jdom-1\.0\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/jdom\/jdom\/1\.0\/jdom-1\.0\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/commons-beanutils\/jars\/commons-beanutils-1\.4\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/commons-beanutils\/commons-beanutils\/1\.4\/commons-beanutils-1\.4\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/commons-logging\/jars\/commons-logging-1\.0\.4\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/commons-logging\/commons-logging\/1\.0\.4\/commons-logging-1\.0\.4\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/commons-collections\/jars\/commons-collections-2\.0\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/commons-collections\/commons-collections\/2\.0\/commons-collections-2\.0\.jar/g;
            $_ =~ s/http:\/\/www\.ibiblio\.org\/maven\/junit\/jars\/junit-3\.8\.1\.jar/file:\/\/$PROJECTS_DIR\/$PID\/lib\/junit\/junit\/3\.8\.1\/junit-3\.8\.1\.jar/g;
            print OUT $_;
        }
        close(IN);
        close(OUT);
    }

}

#
# This subroutine is called by the bug-mining framework for each revision during
# the initialization of the project. Example uses are: converting and caching
# build files or other time-consuming tasks, whose results should be cached.
#
sub initialize_revision {
    my ($self, $rev_id, $vid) = @_;
    $self->SUPER::initialize_revision($rev_id);

    my $work_dir = $self->{prog_root};
    my $result = determine_layout($self, $rev_id);
    die "Unknown layout for revision: ${rev_id}" unless defined $result;

    $self->_add_to_layout_map($rev_id, $result->{src}, $result->{test});
    $self->_cache_layout_map(); # Force cache rebuild
}

1;
