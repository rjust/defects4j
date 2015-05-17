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

Project/Math.pm -- Concrete project instance for Commons-math.

=head1 DESCRIPTION

This module provides all project-specific configurations and methods for the
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
    my $work_dir = shift // "$SCRIPT_DIR/projects";
    my $name = "commons-math";
    my $vcs = Vcs::Git->new($PID,
                            "$REPO_DIR/$name.git",
                            "$work_dir/$PID/commit-db");

    return $class->SUPER::new($PID, $name, $vcs, $work_dir);
}

sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $revision_id) = @_;
    my $dir = $self->{prog_root};
    my $result = _layout1($dir) // _layout2($dir);
    die "Unknown layout for revision: ${revision_id}" unless defined $result;
    return $result;
}


# Remove looping tests in addition to the broken ones
sub fix_tests {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $revision_id) = @_;
    $self->SUPER::fix_tests($revision_id);

    # TODO: Exclusively use version ids rather than revision ids
    $revision_id = $self->lookup($revision_id) if $revision_id =~ /\d+[bf]/;

    my $dir = $self->test_dir($revision_id);

    # TODO: make this more precise (TODO: either explain this TODO or kill it)
    my $file = "$SCRIPT_DIR/build-scripts/$PID/broken_tests";
    if (-e $file) {
        $self->exclude_tests_in_file($file, $dir);
    }
}

# Existing build.xml and default.properties
sub _layout1 {
    my $dir = shift;
    my $src  = `grep 'name="source.home"' $dir/build.xml 2>/dev/null`; chomp $src;
    my $test = `grep 'name="test.home"' $dir/build.xml 2>/dev/null`; chomp $test;

    return undef if ($src eq "" || $test eq "");

    $src =~ s/.*"source\.home"\s*value\s*=\s*"(\S+)".*/$1/;
    $test=~ s/.*"test\.home"\s*value\s*=\s*"(\S+)".*/$1/;

    return {src=>$src, test=>$test};
}

# Generated build.xml (mvn ant:ant) with maven-build.properties
sub _layout2 {
    my $dir = shift;
    my $src  = `grep "<sourceDirectory>" $dir/project.xml 2>/dev/null`; chomp $src;
    my $test = `grep "<unitTestSourceDirectory>" $dir/project.xml 2>/dev/null`; chomp $test;

    return undef if ($src eq "" || $test eq "");

    $src =~ s/.*<sourceDirectory>\s*([^<]+)\s*<\/sourceDirectory>.*/$1/;
    $test=~ s/.*<unitTestSourceDirectory>\s*([^<]+)\s*<\/unitTestSourceDirectory>.*/$1/;

    return {src=>$src, test=>$test};
}

1;

=pod

=head1 SEE ALSO

F<Project.pm>

=cut

