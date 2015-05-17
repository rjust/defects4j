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

Project/Time.pm -- Concrete project instance for Joda-Time.

=head1 DESCRIPTION

This module provides all project-specific configurations and methods for the
Joda-Time project.

=cut
package Project::Time;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "Time";

my $PATH_PREFIX = "JodaTime/";
my $SPLIT_REVISION = '24145245526b789deb025bbb47cdaecdd4b84e04';

sub new {
    my $class = shift;
    my $work_dir = shift // "$SCRIPT_DIR/projects";
    my $name = "joda-time";
    my $vcs = Vcs::Git->new($PID,
                            "$REPO_DIR/$name.git",
                            "$work_dir/$PID/commit-db",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs, $work_dir);
}

sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $revision_id) = @_;
    my $work_dir = $self->{prog_root};
    return (-e "$work_dir/src/main/java") ?
        {src=>"src/main/java", test=>"src/test/java"} :
        {src=>"src/java",      test=>"src/test"};
}


sub _post_checkout {
    my ($vcs, $revision, $work_dir) = @_;
    my $name = $vcs->{prog_name};

    if (-e "$work_dir/JodaTime") {
        system("mv $work_dir/JodaTime/* $work_dir");
    }

    # Check whether ant build file exists
    unless (-e "$work_dir/build.xml") {
        my $generated_buildfile_dir = "$SCRIPT_DIR/build-scripts/$PID/build_files/$revision";
        unless (-e "$generated_buildfile_dir/build.xml") {
            my $build_script_dir = "$SCRIPT_DIR/build-scripts/$PID";
            my $log = `cd $work_dir && patch --dry-run pom.xml ${build_script_dir}/pom.xml.patch`;
             if ($? == 0) {
                print "Patching pom.xml..\n";
                `cd $work_dir && patch pom.xml ${build_script_dir}/pom.xml.patch`;
            }
            print "Maven buildfile -> Ant buildfile for: $revision...";
            Utils::maven_to_ant("$SCRIPT_DIR/build-scripts/$PID/build.xml.patch",
                                $work_dir,
                                $generated_buildfile_dir);
        }
        system("cp $generated_buildfile_dir/* $work_dir") == 0 or die;
    }

    # Check for a broken-build-revision
    my $filename = "${SCRIPT_DIR}/build-scripts/${PID}/broken-builds/build-${revision}.xml";
    if (-e $filename) {
        system ("cp $filename $work_dir/build.xml");
    }
}

sub export_diff {
    my ($self, $rev1, $rev2, $out_file, $path) = @_;
    $path = $PATH_PREFIX . ($path//'') if $self->{_vcs}->comes_before($rev1, $SPLIT_REVISION);
    return $self->{_vcs}->export_diff($rev1, $rev2, $out_file, $path);
}


sub diff {
    my ($self, $rev1, $rev2, $path) = @_;
    $path = $PATH_PREFIX . ($path//'') if $self->{_vcs}->comes_before($rev1, $SPLIT_REVISION);
    return $self->{_vcs}->diff($rev1, $rev2, $path);
}


1;

=pod

=head1 SEE ALSO

F<Project.pm>

=cut

