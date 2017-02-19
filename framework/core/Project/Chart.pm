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

Project::Chart.pm -- L<Project> submodule for JFreeChart.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
JFreeChart project.

=cut
package Project::Chart;

use strict;
use warnings;

use Constants;
use Vcs::Svn;

our @ISA = qw(Project);
my $PID = "Chart";

sub new {
    my $class = shift;
    my $name = "jfreechart";
    my $src  = "source";
    my $test = "tests";
    my $vcs = Vcs::Svn->new($PID,
                            "file://$REPO_DIR/$name/trunk",
                            "$SCRIPT_DIR/projects/$PID/commit-db",
                            \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs, $src, $test);
}

sub _post_checkout {
    # Fix compilation errors if necessary
    @_ == 3 or die $ARG_ERROR;
    my ($self, $revision_id, $work_dir) = @_;

    my $compile_errors = "$SCRIPT_DIR/projects/$PID/compile-errors/";
    opendir(DIR, $compile_errors) or die "could not find compile-error directory.";
    my @entries = readdir(DIR);
    closedir(DIR);

    foreach my $file (@entries) {
        if ($file =~ /-(\d+)-(\d+).diff/) {
            if ($revision_id >= $1 && $revision_id <= $2) {
                $self->{_vcs}->apply_patch($work_dir, "$compile_errors/$file") or confess("Couldn't apply patch ($file): $!");
            }
        }
    }
}

1;
