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

=item * File name of the commit database (L<BUGS_CSV_ACTIVE|Constants>), see below for details

=item * Reference to post-checkout hook (optional) -- if provided, this method is called after each checkout.

=back

=head2 active-bugs csv

The L<BUGS_CSV_ACTIVE|Constants> file has the structure: L<BUGS_CSV_BUGID|Constants>, 
L<BUGS_CSV_COMMIT_BUGGY|Constants>, L<BUGS_CSV_COMMIT_FIXED|Constants>, 
L<BUGS_CSV_ISSUE_ID|Constants>, L<BUGS_CSV_ISSUE_URL|Constants>.

Example for Svn:

  1,2264,2266,983,https://sourceforge.net/p/jfreechart/bugs/983
  2,2240,2242,959,https://sourceforge.net/p/jfreechart/bugs/959

Example for Git:
  1,a9e5c9f99bcc16d734251f682758004a3ecc3a1b,b40ac81d4a81736e2b7536b14db4ad070b598d2e,98,https://github.com/FasterXML/jackson-core/issues/98
  2,098ece8564ed5d37f483c3bfb45be897ed8974cd,38d6e35d1f1a9b48193804925517500de8efee1f,105,https://github.com/FasterXML/jackson-core/issues/105

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

Queries the commit database (L<BUGS_CSV_ACTIVE|Constants>) and returns the C<revision_id> for
the given version id C<vid>. Format of C<vid> checked 
using L<Utils::check_vid(vid)|Utils/"Input validation">.

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

  $vcs->lookup_vid(revision_id)

Returns the C<version_id> for the given revision id.

=cut

sub lookup_vid {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $rev_id) = @_;
    my @answer = grep {$self->lookup($_ . "f") eq $rev_id ||
                       $self->lookup($_ . "b") eq $rev_id} $self->get_bug_ids();
    return -1 unless scalar(@answer) > 0;
    return $answer[0];
}

=pod

  $vcs->num_revision_pairs()

Returns the number of revision pairs in the L<BUGS_CSV_ACTIVE|Constants> file.

=cut

sub num_revision_pairs {
    @_ == 1 or die $ARG_ERROR;
    my ($self) = @_;
    return scalar keys %{$self->{_cache}};
}

=pod

  $project->get_bug_ids()

Returns an array of all bug ids in the L<BUGS_CSV_ACTIVE|Constants> file.

=cut

sub get_bug_ids {
    @_ == 1 or die $ARG_ERROR;
    my ($self) = @_;
    return sort {$a <=> $b} keys %{$self->{_cache}};
}

=pod

  $vcs->B<contains_version_id> C<contains_version_id(vid)

Given a valid version id (C<vid>), this subroutine returns true if C<vid> exists
in the L<BUGS_CSV_ACTIVE|Constants> file and false otherwise.
Format of C<vid> checked using L<Utils::check_vid(vid)|Utils/"Input validation">.
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

Performs a lookup of C<vid> in the L<BUGS_CSV_ACTIVE|Constants> file followed by a checkout of
the corresponding revision with C<revision_id> to F<work_dir>.
Format of C<vid> checked using L<Utils::check_vid(vid)|Utils/"Input validation">.

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
    Utils::exec_cmd($cmd, "Checking out " . _trunc_rev_id($revision_id) . " to $work_dir") or return 0;

    # TODO: The post-checkout should only be called from Project.pm
    #       Avoid confusion and make the _co_hook an attribute of Project rather
    #       than Vcs.
    # $self->{_co_hook}($self, $revision_id, $work_dir) if defined $self->{_co_hook};

    # Write version info file to indicate that this directory is a Defects4J
    # working directory.
    my %config = ();
    $config{$CONFIG_PID} = $self->{pid};
    $config{$CONFIG_VID} = $vid;
    Utils::write_config_file("$work_dir/$CONFIG", \%config);
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
    @_ >= 3 or confess($ARG_ERROR);
    my ($self, $work_dir, $patch_file, $ignore_err) = @_;
    my $cmd = $self->_apply_cmd($work_dir, $patch_file, $ignore_err);
    if (defined($cmd)) {
      return Utils::exec_cmd($cmd, "Apply patch");
    } else {
      return 0;
    }
}

=pod

  _apply_cmd(work_dir, patch_file)

Returns the command to apply the patch (F<patch_file>) to the working directory
(F<work_dir>). Since the file path of some patches needs to be stripped, this
command tries a few dry-runs for the most likely settings before giving up.

=cut

sub _apply_cmd {
    @_ >= 3 or confess($ARG_ERROR);
    my ($self, $work_dir, $patch_file, $ignore_err) = @_;
    # -p1 is the default for git apply (a/src/...) and the most likely option.
    # Try -p0 and -p2 as well before giving up.
    my @try = (1, 0, 2);
    my $log = "";
    for my $n (@try) {
        my $cmd = "cd $work_dir; git apply -p$n --check $patch_file 2>&1";
        $log .= "* $cmd\n";
        $log .= `$cmd`;
        if ($? == 0) {
            print(STDERR "patch applied: $patch_file\n") if $DEBUG;
            return("cd $work_dir; git apply -p$n $patch_file 2>&1");
        }
    }

    if ($ignore_err) {
        return undef;
    }

    confess("Cannot determine how to apply patch!\n" .
            "All attempts failed:\n$log" . "-" x 70 . "\n");
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
# Read the L<BUGS_CSV_ACTIVE|Constants> file and build cache
#
sub _build_db_cache {
    @_ == 1 or die $ARG_ERROR;
    my ($db) = @_;
    open (IN, "<$db") or die "Cannot open $BUGS_CSV_ACTIVE $db: $!";
    my $cache = {};
    
    my $header = <IN>;
    while (<IN>) {
        chomp;
        /(\d+),([^,]+),([^,]+),([^,]+),([^,]+)/ or die "Corrupted $BUGS_CSV_ACTIVE!";
        $cache->{$1} = {b => $2, f => $3, line => $_};
    }
    close IN;

    return $cache;
}

#
# Truncate revision id to 8 characters if necessary
#
sub _trunc_rev_id {
    @_ == 1 or die $ARG_ERROR;
    my ($id) = @_;
    if (length($id) > 8) {
        $id = substr($id, 0, 8);
    }
    return $id;
}

1;
