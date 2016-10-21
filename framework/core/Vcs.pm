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

Vcs.pm -- a simple abstraction for version control systems.

=head1 SYNOPSIS

=head2 Example using Vcs::Svn

  use Vcs::Svn;
  my $vcs = Vcs::Svn->new($project, "repo_url", "commit_db_file", \&_co_hook);

  sub _co_hook {
    my ($vcs, $revision_id, $work_dir) = @_;
    # do some post processing
 }

=head2 New Vcs Submodule

The provided default implementations may be overriden to provide specific behavior.
In most cases it is sufficient to override the following abstract subroutines to provide
a vcs-specific command:

  _checkout_cmd(revision_id, work_dir)

Returns the command to checkout C<revision_id> to the working directory F<work_dir>.

=cut
sub _checkout_cmd { die $ABSTRACT_METHOD; }
=pod

  _apply_cmd(work_dir, patch_file)

Returns the command to apply the patch in file F<patch_file> to the working directory
F<work_dir>.

=cut
sub _apply_cmd { die $ABSTRACT_METHOD; }
=pod

  _diff_cmd(rev1, rev2, path)

Returns the command to compute a diff between two revisions C<rev1> and C<rev2>.
The optional path C<path> is relative to the working directory and used to diff between
certain files or directories.

=cut
sub _diff_cmd { die $ABSTRACT_METHOD; }

=pod

  _rev_date_cmd(rev)

Returns the date of the revision C<rev> or undef if the revision doesn't exist.

=cut
sub _rev_date_cmd { die $ABSTRACT_METHOD; }

=pod

  _get_parent_revisions()

TODO

=cut
sub _get_parent_revisions { die $ABSTRACT_METHOD; }

=head1 DESCRIPTION

This module provides a simple abstraction for version control systems.

=head2 Available submodules

=over 4

=item * L<Vcs::Git>

=item * L<Vcs::Svn>

=back

=cut
package Vcs;

use warnings;
use strict;

use Constants;
use Utils;
use File::Path qw(make_path);
use Carp qw(confess);

=pod

A Vcs object has to be instantiated with:

=over 4

=item * Project name

=item * Repository url

=item * File name of the commit database (commit-db), see below for details

=item * Reference to post-checkout hook (optional) -- if provided, this method is called after each checkout.

=back

=head2 commit-db

The commit-db (csv) file has the structure: C<bug_id,revision_buggy,revision_fixed>.

Example for Svn:

  1,1024,1025
  2,1064,1065

Example for Git:

  1,788193a54e0f1aaa428ccfdd3bb45e32c311c18b,c96ae569bbe0167cfa15caa7f784fdb2e1ecdc12
  2,ab333482c629d33d5484b4af6eb27918382ccc28,f77c5101df42f501d96d0363084dcc9c17400fce

=cut
sub new {
    @_ >= 4 or die $ARG_ERROR;
    my ($class, $pid, $repo, $db, $hook) = @_;
    my $self = {
        pid => $pid,
        repo => $repo,
        commit_db => $db,
        _cache => _build_db_cache($db),
        _co_hook => $hook
    };

    bless $self, $class;
    return $self;
}

=pod

=head2 Object subroutines

  $vcs->lookup(vid)

Queries the commit database (commit-db) and returns the C<revision_id> for
the given version id C<vid>. Format of C<vid>: C<\d+[bf]>.

=cut
sub lookup {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    Utils::check_vid($vid);
    $vid =~ /^(\d+)([bf])$/ or die "Unexpected version id: $vid";
    defined $self->{_cache}->{$1}->{$2} or die "Version id does not exist: $vid!";
    return $self->{_cache}->{$1}->{$2};
}

=pod

  $vcs->lookup_revision_id(revision)

Returns the C<revision_id> for the given revision number or hash.

=cut
sub lookup_revision_id {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $revision) = @_;
    my @answer = grep {$self->lookup($_ . "f") eq $revision ||
                       $self->lookup($_ . "b") eq $revision} $self->get_version_ids();
    return -1 unless scalar(@answer) > 0;
    return $answer[0];
}

=pod

  $vcs->num_revision_pairs()

Returns the number of revision pairs in the C<commit-db>.

=cut
sub num_revision_pairs {
    my $self = shift;
    return scalar keys %{$self->{_cache}};
}

=pod

  $project->get_bug_ids()

Returns an array of all bug ids in the C<commit-db>.

=cut
# TODO: rename subroutine
sub get_version_ids {
    my $self = shift;
    return sort {$a <=> $b} keys %{$self->{_cache}};
}

=pod

  $vcs->B<contains_version_id> C<contains_version_id(vid)

Given a valid version id (C<vid>), this subroutine returns true if C<vid> exists
in the C<commit-db> and false otherwise.
Format of C<vid>: C<\d+[bf]>
This subroutine dies if C<vid> is invalid.

=cut
sub contains_version_id {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $vid) = @_;
    my $result = Utils::check_vid($vid);
    return defined $self->{_cache}->{$result->{bid}}->{$result->{type}};
}

=pod

  $vcs->checkout_vid(vid, work_dir)

Performs a lookup of C<vid> in the C<commit-db> followed by a checkout of
the corresponding revision with C<revision_id> to F<work_dir>.
Format of C<vid>: C<\d+[bf]>.

B<Always performs a clean checkout, i.e., the working directory is deleted before the
checkout, if it already exists>.

=cut
sub checkout_vid {
    @_ == 3 or die $ARG_ERROR;
    my ($self, $vid, $work_dir) = @_;
    Utils::check_vid($vid);
    my $revision_id = $self->lookup($vid);

    # Check whether working directory exists
    if (-d $work_dir) {
        # Check whether we should not delete the existing directory: do not
        # delete if it is not empty or not a previously used working directory

        # Is the existing directory empty?
        opendir(DIR, $work_dir) or die "Could not open directory: $work_dir!";
        my @entries = readdir(DIR);
        closedir(DIR);
        my $dir_empty=1;
        foreach (@entries) {
            next if m/^\.\.?$/;
            $dir_empty=0;
            last;
        }

        # If the directory is not empty check whether it is a previously used
        # working directory, and delete all files if so.
        unless ($dir_empty) {
            my $config = Utils::read_config_file("$work_dir/$CONFIG");
            unless(defined $config) {
                die "Directory exists but is not a previously used working directory: $work_dir";
            }

            foreach (@entries) {
                next if m/^\.\.?$/;
                system("rm -rf $work_dir/$_") == 0 or confess("Failed to clean working directory: $!");
            }
        }
    } else {
        make_path($work_dir) or confess("Failed to create working directory: $!");
    }

    # Get and run specific checkout command
    my $cmd = $self->_checkout_cmd($revision_id, $work_dir);
    return Utils::exec_cmd($cmd, "Check out " . _trunc_rev_id($revision_id) . " to $work_dir");
}

=pod

  $vcs->diff(revision_id_1, revision_id_2 [, path])

Returns the diff between C<revision_id_1> and C<revision_id_2> or C<undef> if
the diff failed. The F<path> argument is optional and can be used to compute a diff
between certain files or directories. Note that C<path> is relative to the working
directory.

=cut
sub diff {
    @_ >= 3 or die $ARG_ERROR;
    my ($self, $rev1, $rev2, $path) = @_;
    my $opt   = defined $path ? "($path)" : "";
    my $descr = sprintf("Diff %.8s:%.8s$opt", $rev1, $rev2);
    my $cmd   = $self->_diff_cmd($rev1, $rev2, $path);

    my $diff;
    if (! Utils::exec_cmd($cmd, $descr, \$diff)) {
        return undef;
    }

    return $diff;
}

=pod

  $vcs->export_diff(revision_id_1, revision_id_2, out_file [, path])

Exports the diff between C<revision_id_1> and C<revision_id_2> to F<out_file>.
The path argument is optional and can be used to compute a diff between certain
files or directories. Note that F<path> is relative to the working directory.

=cut
sub export_diff {
    @_ >= 4 or die $ARG_ERROR;
    my ($self, $rev1, $rev2, $out_file, $path) = @_;
    my $diff = $self->diff($rev1, $rev2, $path);
    return 0 unless defined $diff;

    # Export diff to file
    open(OUT, ">$out_file") or die "Cannot open diff file ($out_file): $!";
    print(OUT $diff);
    close(OUT);

    return 1;
}

=pod

  $vcs->apply_patch(work_dir, patch_file)

Applies the patch provided in F<patch_file> to the working directory F<work_dir>.

=cut
sub apply_patch {
    @_ == 3 or confess($ARG_ERROR);
    my ($self, $work_dir, $patch_file) = @_;
    my $cmd = $self->_apply_cmd($work_dir, $patch_file);
    return Utils::exec_cmd($cmd, "Apply patch");
}

=pod

  $vcs->rev_date(rev)

Returns the date for the revision C<rev>.

=cut
sub rev_date {
    @_ == 2 or confess($ARG_ERROR);
    my ($self, $revision_id) = @_;
    my $cmd = $self->_rev_date_cmd($revision_id);
    my $date;
    if (Utils::exec_cmd($cmd, "Determine revision date", \$date)) {
        chomp $date;
        return $date;
    } else {
        return undef;
    }
}

##########################################################################################
# Helper subroutines

#
# Read commit-db and build cache
#
sub _build_db_cache {
    my $db = shift;
    open (IN, "<$db") or die "Cannot open commit-db $db: $!";
    my $cache = {};
    while (<IN>) {
        chomp;
        /(\d+),([^,]+),([^,]+)/ or die "Corrupted commit-db!";
        $cache->{$1} = {b => $2, f => $3, line => $_};
    }
    close IN;

    return $cache;
}

#
# Truncate revision id to 8 characters if necessary
#
sub _trunc_rev_id {
    my $id = shift;
    if (length($id) > 8) {
        $id = substr($id, 0, 8);
    }
    return $id;
}

1;
