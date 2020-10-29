#-------------------------------------------------------------------------------
# Copyright (c) 2014-2019 René Just, Darioush Jalali, and Defects4J contributors.
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
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "commons-math";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE");

    return $class->SUPER::new($PID, $name, $vcs);
}

#
# Determines the directory layout for sources and tests
#
sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $rev_id) = @_;
    my $dir = $self->{prog_root};
    my $result = _layout1($dir) // _layout2($dir);
    die "Unknown layout for revision: ${rev_id}" unless defined $result;
    return $result;
}

#
# Existing Ant build.xml and default.properties
#
sub _layout1 {
    @_ == 1 or die $ARG_ERROR;
    my ($dir) = @_;
    my $src  = `grep 'name="source.home"' $dir/build.xml 2>/dev/null`; chomp $src;
    my $test = `grep 'name="test.home"' $dir/build.xml 2>/dev/null`; chomp $test;

    return undef if ($src eq "" || $test eq "");

    $src =~ s/.*"source\.home"\s*value\s*=\s*"(\S+)".*/$1/;
    $test=~ s/.*"test\.home"\s*value\s*=\s*"(\S+)".*/$1/;

    return {src=>$src, test=>$test};
}

#
# Generated build.xml (from mvn ant:ant) with maven-build.properties
#
sub _layout2 {
    @_ == 1 or die $ARG_ERROR;
    my ($dir) = @_;
    my $src  = `grep "<sourceDirectory>" $dir/project.xml 2>/dev/null`; chomp $src;
    my $test = `grep "<unitTestSourceDirectory>" $dir/project.xml 2>/dev/null`; chomp $test;

    return undef if ($src eq "" || $test eq "");

    $src =~ s/.*<sourceDirectory>\s*([^<]+)\s*<\/sourceDirectory>.*/$1/;
    $test=~ s/.*<unitTestSourceDirectory>\s*([^<]+)\s*<\/unitTestSourceDirectory>.*/$1/;

    return {src=>$src, test=>$test};
}

#
# Remove looping tests in addition to the broken ones
#
sub fix_tests {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    Utils::check_vid($vid);

    $self->SUPER::fix_tests($vid);

    my $dir = $self->test_dir($vid);

    # TODO: Check whether these tests should be excluded on a per-version basis
    my $file = "$PROJECTS_DIR/$PID/broken_tests";
    if (-e $file) {
        $self->exclude_tests_in_file($file, $dir);
    }
}

1;
