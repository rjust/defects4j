#-------------------------------------------------------------------------------
# Copyright (c) 2014-2017 René Just, Darioush Jalali, and Defects4J contributors.
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

Project::Math.pm -- L<Project> submodule for Commons-math.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
Commons-math project.

=cut
package Project::Math;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "Math";

sub new {
    my $class = shift;
    my $name = "commons-math";
    my $src  = "src/main/java";
    my $test = "src/test";
    my $vcs = Vcs::Git->new($PID,
                            "$REPO_DIR/$name.git",
                            "$SCRIPT_DIR/projects/$PID/commit-db");

    return $class->SUPER::new($PID, $name, $vcs, $src, $test);
}

sub src_dir {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    Utils::check_vid($vid);

    # Init dir_map if necessary
    $self->_build_dir_map();

    # Get revision hash
    my $revision_id = $self->lookup($vid);

    # Get src directory from lookup table
    my $src = $self->{_dir_map}->{$revision_id}->{src};
    return $src if defined $src;

    # Get default src dir if not listed in _dir_map
    return $self->SUPER::src_dir($vid);
}

sub test_dir {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    Utils::check_vid($vid);

    # Init dir_map if necessary
    $self->_build_dir_map();

    # Get revision hash
    my $revision_id = $self->lookup($vid);

    # Get test directory from lookup table
    my $test = $self->{_dir_map}->{$revision_id}->{test};
    return $test if defined $test;

    # Get default test dir if not listed in _dir_map
    return $self->SUPER::test_dir($vid);
}

sub _build_dir_map {
    my $self = shift;

    return if defined $self->{_dir_map};

    my $map_file = "$SCRIPT_DIR/projects/$PID/dir_map.csv";
    open (IN, "<$map_file") or die "Cannot open directory map $map_file: $!";
    my $cache = {};
    while (<IN>) {
        chomp;
        /([^,]+),([^,]+),(.+)/ or next;
        $cache->{$1} = {src=>$2, test=>$3};
    }
    close IN;
    $self->{_dir_map}=$cache;
}


#
# Remove loopoing tests in addition to the broken ones
#
sub fix_tests {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    Utils::check_vid($vid);

    $self->SUPER::fix_tests($vid);

    my $dir = $self->test_dir($vid);

    # TODO: make this more precise
    my $file = "$SCRIPT_DIR/projects/$PID/broken_tests";
    if (-e $file) {
        $self->exclude_tests_in_file($file, $dir);
    }
}

1;
