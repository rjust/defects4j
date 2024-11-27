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

Project::JacksonDatabind.pm -- L<Project> submodule for jackson-databind.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
jackson-databind project.

=cut
package Project::JacksonDatabind;

use strict;
use warnings;

use Constants;
use Vcs::Git;
use File::Copy;

our @ISA = qw(Project);
my $PID  = "JacksonDatabind";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "jackson-databind";
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

    # Fix compilation errors if necessary
    my $compile_errors = "$PROJECTS_DIR/$self->{pid}/compile-errors/";
    opendir(DIR, $compile_errors) or die "Could not find compile-errors directory.";
    my @entries = readdir(DIR);
    closedir(DIR);
    foreach my $file (@entries) {
        if ($file =~ /-(\d+)-(\d+)(.optional)?.diff/) {
            my $opt = $3;
            if ($bid >= $1 && $bid <= $2) {
                my $ret = $self->apply_patch($work_dir, "$compile_errors/$file", $opt);
                if (!$ret && !$opt) {
                    confess("Couldn't apply patch ($file): $!");
                }
            }
        }
    }

    # JacksonDatabind has a Module class. Java 9 introduced a Module system for organizing code.
    # This created a compile time ambiguity. To fix this, we attempt to convert all references
    # to a JacksonDatabind Module to com.fasterxml.jackson.databind.Module.
    my $cmd = "grep -lR ' extends Module\$' $work_dir ";
    my $log = `$cmd`;
    my $ret = $?;
    if ($ret == 0 && length($log) > 0) {
        Utils::exec_cmd("grep -lR ' extends Module\$' $work_dir | xargs sed -i'.bak' -e 's/ extends Module\$/ extends com.fasterxml.jackson.databind.Module/'", "Correct Module ambiguity 1") or die;
    }

    $cmd = "grep -lR ' Module ' $work_dir ";
    $log = `$cmd`;
    $ret = $?;
    if ($ret == 0 && length($log) > 0) {
        Utils::exec_cmd("grep -lR ' Module ' $work_dir | xargs sed -i'.bak' -e 's/ Module / com.fasterxml.jackson.databind.Module /'", "Correct Module ambiguity 2") or die;
    }

    $cmd = "grep -lR '<Module>' $work_dir ";
    $log = `$cmd`;
    $ret = $?;
    if ($ret == 0 && length($log) > 0) {
        Utils::exec_cmd("grep -lR '<Module>' $work_dir | xargs sed -i'.bak' -e 's/<Module>/<com.fasterxml.jackson.databind.Module>/'", "Correct Module ambiguity 3") or die;
    }

    $cmd = "grep -lR '(Module)' $work_dir ";
    $log = `$cmd`;
    $ret = $?;
    if ($ret == 0 && length($log) > 0) {
        Utils::exec_cmd("grep -lR '(Module)' $work_dir | xargs sed -i'.bak' -e 's/(Module)/(com.fasterxml.jackson.databind.Module)/'", "Correct Module ambiguity 4") or die;
    }

    $cmd = "grep -lR 'new Module()' $work_dir ";
    $log = `$cmd`;
    $ret = $?;
    if ($ret == 0 && length($log) > 0) {
        Utils::exec_cmd("grep -lR 'new Module()' $work_dir | xargs sed -i'.bak' -e 's/new Module()/new com.fasterxml.jackson.databind.Module()/'", "Correct Module ambiguity 5") or die;
    }

    my $project_dir = "$PROJECTS_DIR/$self->{pid}";
    # Check whether ant build file exists
    unless (-e "$work_dir/build.xml") {
        my $build_files_dir = "$PROJECTS_DIR/$PID/build_files/$rev_id";
        if (-d "$build_files_dir") {
            Utils::exec_cmd("cp -r $build_files_dir/* $work_dir", "Copy generated Ant build file") or die;
        }
    }

    # Copy generated file into place
    my $version = "UNKNOWN";

    open(IN,'<'."$work_dir/maven-build.properties") or die $!;
    while(my $line = <IN>) {
        if ($line =~ /maven\.build\.finalName/) {
            my @words = split /-/, $line;
            $version = $words[2];
        }
    } 
    close(IN);
    
    if ($version ne "UNKNOWN"){
        copy($project_dir."/generated_sources/".$version."/PackageVersion.java", $work_dir."/src/main/java/com/fasterxml/jackson/databind/cfg/PackageVersion.java");
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
    my $result = {src=>"src/main/java", test=>"src/test/java"};

    $self->_add_to_layout_map($rev_id, $result->{src}, $result->{test});
    $self->_cache_layout_map(); # Force cache rebuild
}

1;
