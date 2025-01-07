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

Project::Codec.pm -- L<Project> submodule for commons-codec.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
commons-codec project.

=cut
package Project::Codec;

use strict;
use warnings;

use Constants;
use Vcs::Git;
use File::Copy;

our @ISA = qw(Project);
my $PID  = "Codec";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "commons-codec";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs);
}

##
## Determines the directory layout for sources and tests
##
sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $rev_id) = @_;
    my $work_dir = $self->{prog_root};

    # Only two sets of layouts in this case
    my $result;
    if (-e "$work_dir/src/main"){
      $result = {src=>"src/main/java", test=>"src/test/java"};
    }
    if (-e "$work_dir/src/java"){
      $result = {src=>"src/java", test=>"src/test"};
    }
    die "Unknown layout for revision: ${rev_id}" unless defined $result;
    return $result;
}

#
# Post-checkout tasks include, for instance, providing cached build files,
# fixing compilation errors, etc.
#
sub _post_checkout {
    my ($self, $rev_id, $work_dir) = @_;

    # Set source and target version in javac targets.
    my $jvm_version="1.6";

    if (-e "$work_dir/build.xml") {
        rename("$work_dir/build.xml", "$work_dir/build.xml.bak");
        open(IN, "<$work_dir/build.xml.bak") or die $!;
        open(OUT, ">$work_dir/build.xml") or die $!;
        while(<IN>) {
            my $l = $_;
            $l =~ s/(<javac srcdir="\$\{source.home\}" destdir="\$\{build.home\}\/classes" debug="\$\{compile.debug\}")/$1 target="${jvm_version}" source="${jvm_version}"/g;
            $l =~ s/(<javac srcdir="\$\{test.home\}" destdir="\$\{build.home\}\/classes" debug="\$\{compile.debug\}")/$1 target="${jvm_version}" source="${jvm_version}"/g;

            print OUT $l;
        }
        close(IN);
        close(OUT);
    } else {
        my $build_files_dir = "$PROJECTS_DIR/$PID/build_files/$rev_id";
        if (-d "$build_files_dir") {
            Utils::exec_cmd("cp -r $build_files_dir/* $work_dir", "Copy generated Ant build file") or die;
        }
    }

    # Convert the file encoding of problematic files
    my $result = determine_layout($self, $rev_id);
    Utils::convert_file_encoding($work_dir."/".$result->{test}."/org/apache/commons/codec/binary/Base64Test.java");
    Utils::convert_file_encoding($work_dir."/".$result->{test}."/org/apache/commons/codec/language/ColognePhoneticTest.java");
    Utils::convert_file_encoding($work_dir."/".$result->{test}."/org/apache/commons/codec/language/DoubleMetaphoneTest.java");
    Utils::convert_file_encoding($work_dir."/".$result->{test}."/org/apache/commons/codec/language/SoundexTest.java");

    # Copy in a missing dependency
    my $project_dir = "$PROJECTS_DIR/$self->{pid}";
    if (-d $work_dir."/src/main/resources"){
        copy("$project_dir/lib/org/apache/commons/commons-lang3/3.8.1/commons-lang3-3.8.1.jar", $work_dir."/src/main/resources/commons-lang3-3.8.1.jar");
        if (-e $work_dir."/build.xml"){
           rename("$work_dir"."/build.xml", "$work_dir"."/build.xml".'.bak');
           open(IN, '<'."$work_dir"."/build.xml".'.bak') or die $!;
           open(OUT, '>'."$work_dir"."/build.xml") or die $!;
           while(<IN>) {
               $_ =~ s/\<pathelement location=\"\$\{hamcrest.jar\}\"\/\>/\<pathelement location=\"\$\{hamcrest.jar\}\"\/\>\n\<pathelement location=\"src\/main\/resources\/commons-lang3-3.8.1.jar\"\/\>/g;
               print OUT $_;
           }
           close(IN);
           close(OUT); 
        }
    }

    # Set default Java target to 6.
    if (-e "$work_dir/default.properties") {
        Utils::sed_cmd("s/1\.[1-5]/1.6/", "$work_dir/default.properties");
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
    my $result = determine_layout($self, $rev_id);
    die "Unknown layout for revision: ${rev_id}" unless defined $result;

    $self->_add_to_layout_map($rev_id, $result->{src}, $result->{test});
    $self->_cache_layout_map(); # Force cache rebuild
}

1;
