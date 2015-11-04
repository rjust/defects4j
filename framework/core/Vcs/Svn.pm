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

Vcs::Svn.pm -- L<Vcs> submodule for Svn.

=head1 DESCRIPTION

This module provides all specific configurations and subroutines for the Svn Vcs.

=cut
package Vcs::Svn;

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
    return "svn -r ${revision_id} co $self->{repo} $work_dir";
}

sub _apply_cmd {
    @_ >= 3 or die $ARG_ERROR;
    my ($self, $work_dir, $patch_file, $path) = @_;
    # Path to working directory if provided
    $work_dir = "$work_dir/$path" if defined $path;
#    return "svn patch $patch_file $work_dir 2>&1";
    return "cd $work_dir; patch -p0 < $patch_file 2>&1";
}

sub _diff_cmd {
    @_ >= 3 or die $ARG_ERROR;
    my ($self, $rev1, $rev2, $path) = @_;
    $path = defined $path ? "/$path" : "";
    return "svn diff -r$rev1:$rev2 $self->{repo}$path";
}
}

# This method needs to be overrided as svn patch returns 0 even with a
# failure.
#sub apply_patch {
#    @_ >= 3 or die $ARG_ERROR;
#    my ($self, $work_dir, $patch_file, $path) = @_;
#    print "Applying patch ... ";
#    my $cmd = $self->_apply_cmd($work_dir, $patch_file, $path);
#    my $log = `$cmd`; my $ret = $?;
#    unless ($ret != 0 || $log=~/rejected/m) {
#        print "OK\n";
#        return $ret;
#    } else {
#        print "FAIL\n$log";
#        return 1; # TODO: fix this to be retval if non-zero
#    }
#}


1;
