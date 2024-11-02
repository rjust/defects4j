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

Project::Gson.pm -- L<Project> submodule for gson.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
gson project.

=cut
package Project::Gson;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "Gson";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "gson";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs);
}

#
# Post-checkout tasks include, for instance, providing cached build files,
# fixing compilation errors, etc.
#
sub _post_checkout {
    my ($self, $rev_id, $work_dir) = @_;

    my $bid = Utils::get_bid($work_dir);

    # All relevant files live in the gson subdirectory
    $work_dir .= "/gson/";

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
                        or confess("Couldn't apply patch ($file): $!");
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

    # Set default Java target to 6.
    Utils::sed_cmd("s/source=\\\"1\.[1-5]\\\"/source=\\\"1.6\\\"/", "$work_dir/maven-build.xml");
    Utils::sed_cmd("s/target=\\\"1\.[1-5]\\\"/target=\\\"1.6\\\"/", "$work_dir/maven-build.xml");
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
    $work_dir .= "/gson/";

    my $result = {src=>"gson/src/main/java", test=>"gson/src/test/java"};
    die "Unknown layout for revision: ${rev_id}" unless defined $result;

    $self->_add_to_layout_map($rev_id, $result->{src}, $result->{test});
    $self->_cache_layout_map(); # Force cache rebuild
}

1;
