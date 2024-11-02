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

# The location of all generated build files
my $GEN_BUILDFILE_DIR = "$PROJECTS_DIR/$PID/build_files";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "joda-time";
    my $vcs = Vcs::Git->new($PID,
                            "$REPO_DIR/$name.git",
                            "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs);
}

sub _post_checkout {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $rev_id, $work_dir) = @_;

    my $bid = Utils::get_bid($work_dir);

    # remove the JodaTime super directory (move things one dir up)
    if (-e "$work_dir/JodaTime") {
        system("mv $work_dir/JodaTime/* $work_dir");
    }

    # Fix compilation errors if necessary.
    # Run this as the first step to ensure that patches are applicable to
    # unmodified source files.
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

    my $project_dir = "$PROJECTS_DIR/$self->{pid}";
    # Check whether ant build file exists
    unless (-e "$work_dir/build.xml") {
        Utils::exec_cmd("cp $GEN_BUILDFILE_DIR/$rev_id/* $work_dir",
                "Copy generated Ant build file") or die;
    }

    # Check for a broken-build-revision
    my $filename = "$project_dir/broken-builds/build-${rev_id}.xml";
    if (-e $filename) {
        Utils::exec_cmd("cp $filename $work_dir/build.xml",
                "Fix broken build") or die;
    }
}

sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $rev_id) = @_;
    my $work_dir = $self->{prog_root};
    if (-e "$work_dir/src/main/java") {
        return {src=>"src/main/java", test=>"src/test/java"};
    } elsif(-e "$work_dir/src/java") {
        return {src=>"src/java", test=>"src/test"};
    } else {
        die "Unknown directory layout";
    }
}

#
# Create Ant build files, if necessary
#
sub initialize_revision {
    my ($self, $rev_id, $vid) = @_;
    $self->SUPER::initialize_revision($rev_id);

    my $project_dir = "$PROJECTS_DIR/$self->{pid}";
    my $work_dir = $self->{prog_root};
    # Create ant build file if necessary
    unless (-e "$work_dir/build.xml") {
        unless (-e "$GEN_BUILDFILE_DIR/$rev_id/build.xml") {
            # Patch maven build file before converting it
            `cd $work_dir && patch --dry-run pom.xml $project_dir/pom.xml.patch`;
            if ($? == 0) {
                Utils::exec_cmd("cd $work_dir && patch pom.xml $project_dir/pom.xml.patch",
                        "Patch Maven build file: " . _trunc_rev_id($rev_id))
                        or die;
            }
            my $cmd = "cd $work_dir && mvn ant:ant 2>&1" .
                      " && patch build.xml $project_dir/build.xml.patch 2>&1" .
                      " && cp maven-build.* $GEN_BUILDFILE_DIR/$rev_id 2>&1" .
                      " && cp build.xml $GEN_BUILDFILE_DIR/$rev_id 2>&1";
            Utils::exec_cmd($cmd, "Convert Maven to Ant build file: " .  _trunc_rev_id($rev_id)) or die;
        }
        Utils::exec_cmd("cp $GEN_BUILDFILE_DIR/* $work_dir",
                "Copy generated Ant build file") or die;
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
