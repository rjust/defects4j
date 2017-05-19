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

Project::Closure.pm -- L<Project> submodule for Closure compiler.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
Closure compiler project.

=cut
package Project::Closure;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "Closure";

sub new {
    my $class = shift;
    my $name = "closure-compiler";
    my $src  = "src";
    my $test = "test";
    my $vcs = Vcs::Git->new($PID,
                            "$REPO_DIR/$name.git",
                            "$SCRIPT_DIR/projects/$PID/commit-db",
                    \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs, $src, $test);
}

sub _post_checkout {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $revision_id, $work_dir) = @_;

    open FH, "$work_dir/build.xml" or die $!;
    my $build_file = do { local $/; <FH> };
    close FH;

    $build_file =~ s/debug=".*"//g;
    $build_file =~ s/<javac (.*)/<javac debug="true" $1/g;

    open FH, ">$work_dir/build.xml" or die $!;
    print FH $build_file;
    close FH;
}

1;
