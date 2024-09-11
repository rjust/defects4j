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

Project::Csv.pm -- L<Project> submodule for commons-csv.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
commons-csv project.

=cut
package Project::Csv;

use strict;
use warnings;

use Constants;
use Vcs::Git;
use File::Copy;

our @ISA = qw(Project);
my $PID  = "Csv";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "commons-csv";
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

    my $project_dir = "$PROJECTS_DIR/$self->{pid}";
    # Check whether ant build file exists
    unless (-e "$work_dir/build.xml") {
        my $build_files_dir = "$PROJECTS_DIR/$PID/build_files/$rev_id";
        if (-d "$build_files_dir") {
            Utils::exec_cmd("cp -r $build_files_dir/* $work_dir", "Copy generated Ant build file") or die;
        }
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
