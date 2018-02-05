#-------------------------------------------------------------------------------
# Copyright (c) 2014-2018 René Just, Darioush Jalali, and Defects4J contributors.
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

Project::Time.pm -- L<Project> submodule for Joda-Time.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
Joda-Time project.

=cut
package Project::Time;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "Time";

sub new {
    my ($class, $work_dir, $commit_db, $build_file) = @_;

    my $name = "joda-time";
    $work_dir = $work_dir // "$SCRIPT_DIR/projects";
    my $src  = "src/main/java";
    my $test = "src/test/java";
    my $vcs = Vcs::Git->new($PID,
                            "$REPO_DIR/$name.git",
                             ($commit_db // "$SCRIPT_DIR/projects/$PID/commit-db"),
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs, $src, $test, $build_file, $work_dir);
}

#TODO should these SCRIPT_DIR/projects actually be work dir?
sub _post_checkout {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $revision_id, $prog_root) = @_;

    # remove the JodaTime super directory (move things one dir up)
    if (-e "$prog_root/JodaTime") {
        system("mv $prog_root/JodaTime/* $prog_root");
    }

    # Check whether ant build file exists
    unless (-e "$prog_root/build.xml") {
        system("cp $SCRIPT_DIR/projects/$PID/build_files/$revision_id/* $prog_root");
    }

    # Check for a broken-build-revision
    my $id = $self->lookup_revision_id($revision_id); # TODO: very ugly.
    my $filename = "$SCRIPT_DIR/projects/${PID}/broken-builds/build-${id}.xml";
    if (-e $filename) {
        system ("cp $filename $prog_root/build.xml");
    }
}

# special path for diff based on the file structure in those commits
sub get_base_diff_path {
    my ($self, $rev1, $rev2) = @_;

    # TODO use Utils::files_in_commit
    # look at the diff and check the paths of the files
    my $cmd = "cd $self->{'_vcs'}->{'repo'}; git diff-tree --no-commit-id --name-only -r"; # partial command

    # will output errors automatically
    my $rev1_files = `$cmd $rev1`;
    my $rev2_files = `$cmd $rev2`;
    if ((! $rev1_files) || (! $rev2_files)) {
        return ""; # no files in one of the commits
    }

    # if they are both JodaTime/ then we adapt, if they are different, we cant really recover reliably
    my $rev1_matches = ($rev1_files =~ /^JodaTime.*/m);
    my $rev2_matches = ($rev2_files =~ /^JodaTime.*/m);
    if ($rev1_matches && $rev2_matches) {
        return "JodaTime/";
    } elsif ($rev1_matches ^ $rev2_matches) {
        # cant reliably recover better throw and error
        die "Diff needs manual adjustment for paths, revision_id $rev1, $rev2";
    } else {
        return "";
    }
}

sub export_diff {
    my ($self, $rev1, $rev2, $out_file, $path) = @_;
    $path = $self->get_base_diff_path($rev1,$rev2) . ($path//"");
    return $self->{_vcs}->export_diff($rev1, $rev2, $out_file, $path);
}

sub diff {
    my ($self, $rev1, $rev2, $path) = @_;
    $path = $self->get_base_diff_path($rev1,$rev2) . ($path//"");
    return $self->{_vcs}->diff($rev1, $rev2, $path);
}


1;
