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
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "closure-compiler";
    my $vcs = Vcs::Git->new($PID,
                            "$REPO_DIR/$name.git",
                            "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE",
                    \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs);
}

#
# Determines the directory layout for sources and tests
#
sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $rev_id) = @_;
    return {src=>'src', test=>'test'};
}

sub _post_checkout {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $rev_id, $work_dir) = @_;

    my $bid = Utils::get_bid($work_dir);

    # Fix compilation errors if necessary
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

    open FH, "$work_dir/build.xml" or die $!;
    my $build_file = do { local $/; <FH> };
    close FH;

    $build_file =~ s/debug=".*"//g;
    $build_file =~ s/<javac (.*)/<javac debug="true" $1/g;

    # Set source and target version in javac targets.
    my $jvm_version = "1.6";

    unless ($build_file =~ m/<property name="ant.build.javac.source"/) {
        $build_file =~ s/(<project name="compiler"[^>]+>)/$1\n<property name="ant.build.javac.target" value="${jvm_version}"\/>\n<property name="ant.build.javac.source" value="${jvm_version}"\/>/s;
    }

    open FH, ">$work_dir/build.xml" or die $!;
    print FH $build_file;
    close FH;

    # Set default Java target to 6.
    if (-e "$work_dir/lib/rhino/build.properties") {
        # either these:
        Utils::sed_cmd("s/source-level: 1\.[1-5]/source-level ${jvm_version}/", "$work_dir/lib/rhino/build.properties");
        Utils::sed_cmd("s/target-jvm: 1\.[1-5]/target-jvm ${jvm_version}/", "$work_dir/lib/rhino/build.properties");
    }
    if (-e "$work_dir/lib/rhino/src/mozilla/js/rhino/build.properties") {
        # or these:
        Utils::sed_cmd("s/source-level: 1\.[1-5]/source-level ${jvm_version}/", "$work_dir/lib/rhino/src/mozilla/js/rhino/build.properties");
        Utils::sed_cmd("s/target-jvm: 1\.[1-5]/target-jvm ${jvm_version}/", "$work_dir/lib/rhino/src/mozilla/js/rhino/build.properties");
    }
}

1;
