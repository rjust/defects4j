#-------------------------------------------------------------------------------
# Copyright (c) 2014-2018 René Just, Darioush Jalali, and Defects4J contributors.
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

Project::Compress.pm -- L<Project> submodule for commons-compress.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
commons-compress project.

=cut
package Project::Compress;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "Compress";

my $GEN_BUILDFILE_DIR = "$PROJECTS_DIR/$PID/build_files";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "commons-compress";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$PROJECTS_DIR/$PID/commit-db",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs);
}

#
# Determines the directory layout for sources and tests
#
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
    # For versions using Maven, check whether maven-ant build file exists in work dir, if not, copy it over
    if (-e "$work_dir/pom.xml") {
        system("cp $GEN_BUILDFILE_DIR/$rev_id/* $work_dir");
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
    # Run maven-ant plugin and overwrite the original build.xml whenever a maven build file exists
    if (-e "$work_dir/pom.xml"){
      system("mkdir -p $GEN_BUILDFILE_DIR/$rev_id");
      my $cmd = " cd $work_dir" .
                " && mvn ant:ant -Doverwrite=true 2>&1" .
                " && cp maven-build.* $GEN_BUILDFILE_DIR/$rev_id 2>&1" .
                " && cp build.xml $GEN_BUILDFILE_DIR/$rev_id 2>&1";
         Utils::exec_cmd("cp $GEN_BUILDFILE_DIR/$rev_id/* $work_dir 2>&1",
                 "Copy generated Ant build file" );
      }
}

1;
