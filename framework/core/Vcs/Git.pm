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

Vcs::Git.pm -- L<Vcs> submodule for Git.

=head1 DESCRIPTION

This module provides all specific configurations and subroutines for the Git Vcs.

=cut
package Vcs::Git;

use warnings;
use strict;
use Vcs;
use Constants;

our @ISA = qw(Vcs);

{
no warnings 'redefine';

sub _checkout_cmd {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $revision_id, $work_dir) = @_;
    return "git clone $self->{repo} ${work_dir} 2>&1 && cd $work_dir && git checkout $revision_id 2>&1";
}

sub _apply_cmd {
    @_ == 3 or confess($ARG_ERROR);
    my ($self, $work_dir, $patch_file) = @_;
    return "cd $work_dir && git apply $patch_file 2>&1";
}

sub _diff_cmd {
    @_ >= 3 or die $ARG_ERROR;
    my ($self, $rev1, $rev2, $path) = @_;
    $path = defined $path ? "-- $path $path" : "";
    return "git --git-dir=$self->{repo} diff --binary ${rev1} ${rev2} $path";
}

sub _rev_date_cmd {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $revision_id) = @_;
    return "git --git-dir=$self->{repo} show -s --format=%ci ${revision_id}";
}
}

1;
