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

Query.pm -- Infrastructure for querying the metadata for project and 
version-specific properties.

=head1 DESCRIPTION

This module provides an internal API for querying the metadata. This 
functionality externally surfaces through the L<query|d4j::d4j-query> and
L<bids|d4j::d4j-bids> commands. 

=cut

package Query;

use strict;
use warnings;

use Constants;
use Utils;
use Project;

=pod

=head2 External API

=over 4

=item C<Query::get_fields()>

Used to retrieve a list of legal metadata fields. The current value of each field
is defined in L<Constants>. This method must be modified to add or remove legal
fields. 

=cut

sub get_fields {
    # All fields should be defined in Constants
    my @fields = ($BUGS_CSV_BUGID, $BUGS_CSV_COMMIT_BUGGY, $BUGS_CSV_COMMIT_FIXED, $BUGS_CSV_ISSUE_ID, $BUGS_CSV_ISSUE_URL, $BUGS_CSV_DEPRECATED_WHEN, $BUGS_CSV_DEPRECATED_WHY, $METADATA_LOADED_CLASSES_SRC, $METADATA_LOADED_CLASSES_TEST, $METADATA_MODIFIED_CLASSES, $METADATA_RELEVANT_TESTS, $METADATA_TRIGGER_TESTS, $METADATA_TRIGGER_CAUSE, $METADATA_PROJECT_ID, $METADATA_PROJECT_NAME, $METADATA_BUILD_FILE, $METADATA_VCS, $METADATA_REPOSITORY, $METADATA_COMMIT_DB, $METADATA_DATE_BUGGY, $METADATA_DATE_FIXED);
    return @fields;
}

=pod

=item C<Query::check_fields(requested_fields)>

Checks whether an array of requested fields contains only legal entries.
If illegal fields are in the list, the query is killed. The list of legal
fields is defined by C<Query::get_fields()>.

=cut

sub check_fields {
    my @requested = @_;
    my @all_fields = get_fields();
    foreach my $field (@requested) {
        unless (grep $_ eq $field, @all_fields) {
            die "Requested field \"$field\" is invalid";
        }
    }
}

=pod

=item C<Query::query_metadata(project_id, [D|C|A], requested_fields)>

Queries are executed through this subroutine. Accepts a project ID,
accepts a project ID, a flag indicating which bugs to query, and a set 
of fields. The flag can have values C (only active bugs), D (only deprecated
bugs), or A (all bugs). Returns a dictionary associating bug IDs with a
dictionary containing values for each requested metadata field. 
For examples of usage, see C<d4j-query> and C<d4j-print-bugs>. 

=cut

sub query_metadata {
    my ($pid, $flag, @requested) = @_;
    my $active_bugs = "$PROJECTS_DIR/$pid/$BUGS_CSV_ACTIVE";
    my $deprecated_bugs = "$PROJECTS_DIR/$pid/$BUGS_CSV_DEPRECATED";

    # Check query for unavailable fields
    check_fields(@requested);

    my %results;
    my $project = Project::create_project($pid);
    my @necessary = @requested;
    push @necessary, $BUGS_CSV_BUGID;
    push @necessary, $BUGS_CSV_COMMIT_BUGGY;
    push @necessary, $BUGS_CSV_COMMIT_FIXED;

    # First, get results from the active and deprecated-bugs CSV files.

    if ($flag ne "D") {
        %results = _read_bug_csv($active_bugs, @necessary);

        if (grep $_ eq $METADATA_COMMIT_DB, @requested) {
            foreach my $bug_id (keys %results) {
                $results{$bug_id}{$METADATA_COMMIT_DB} = $active_bugs;
            }
        }
    }

    if ($flag eq "D" || $flag eq "A") {
        my %dep_results = _read_bug_csv($deprecated_bugs, @necessary);
        if (grep $_ eq $METADATA_COMMIT_DB, @requested) {
            foreach my $bug_id (keys %dep_results) {
                $dep_results{$bug_id}{$METADATA_COMMIT_DB} = $deprecated_bugs;
            }
        }

        foreach my $bug_id (sort { $a <=> $b } keys %dep_results) {
            $results{$bug_id} = $dep_results{$bug_id};
        }
    }

    # Now, get results from other metadata and associate with bug ID

    if (grep $_ eq $METADATA_LOADED_CLASSES_SRC, @requested) {
        my %metadata = _read_class_list("$pid/loaded_classes", ".src", keys %results);

        foreach my $bug_id (keys %metadata) {
            $results{$bug_id}{$METADATA_LOADED_CLASSES_SRC} = $metadata{$bug_id};
        }
    }

    if (grep $_ eq $METADATA_LOADED_CLASSES_TEST, @requested) {
        my %metadata = _read_class_list("$pid/loaded_classes", ".test", keys %results);

        foreach my $bug_id (keys %metadata) {
            $results{$bug_id}{$METADATA_LOADED_CLASSES_TEST} = $metadata{$bug_id};
        }
    }

    if (grep $_ eq $METADATA_MODIFIED_CLASSES, @requested) {
        my %metadata = _read_class_list("$pid/modified_classes", ".src", keys %results);

        foreach my $bug_id (keys %metadata) {
            $results{$bug_id}{$METADATA_MODIFIED_CLASSES} = $metadata{$bug_id};
        }
    }

    if (grep $_ eq $METADATA_RELEVANT_TESTS, @requested) {
        my %metadata = _read_class_list("$pid/relevant_tests", "", keys %results);

        foreach my $bug_id (keys %metadata) {
            $results{$bug_id}{$METADATA_RELEVANT_TESTS} = $metadata{$bug_id};
        }
    }

    if (grep $_ eq $METADATA_TRIGGER_TESTS, @requested) {
        my %metadata = _read_stack_traces(0, "$pid/trigger_tests", keys %results);

        foreach my $bug_id (keys %metadata) {
            $results{$bug_id}{$METADATA_TRIGGER_TESTS} = $metadata{$bug_id};
        }
    }

    if (grep $_ eq $METADATA_TRIGGER_CAUSE, @requested) {
        my %metadata = _read_stack_traces(1, "$pid/trigger_tests", keys %results);

        foreach my $bug_id (keys %metadata) {
            $results{$bug_id}{$METADATA_TRIGGER_CAUSE} = $metadata{$bug_id};
        }
    }

    if (grep $_ eq $METADATA_PROJECT_ID, @requested) {
        foreach my $bug_id (keys %results) {
            $results{$bug_id}{$METADATA_PROJECT_ID} = $pid;
        }
    }

    if (grep $_ eq $METADATA_PROJECT_NAME, @requested) {
        foreach my $bug_id (keys %results) {
            $results{$bug_id}{$METADATA_PROJECT_NAME} = $project->{prog_name};
        }
    }

    if (grep $_ eq $METADATA_BUILD_FILE, @requested) {
        foreach my $bug_id (keys %results) {
            $results{$bug_id}{$METADATA_BUILD_FILE} = $PROJECTS_DIR."/".$pid."/".$pid.".build.xml";
        }
    }

    if (grep $_ eq $METADATA_VCS, @requested) {
        foreach my $bug_id (keys %results) {
            $results{$bug_id}{$METADATA_VCS} = ref $project->{_vcs};
        }
    }

    if (grep $_ eq $METADATA_REPOSITORY, @requested) {
        foreach my $bug_id (keys %results) {
            $results{$bug_id}{$METADATA_REPOSITORY} = $project->{_vcs}->{repo};
        }
    }

    if (grep $_ eq $METADATA_DATE_BUGGY, @requested) {
        foreach my $bug_id (keys %results) {
            $results{$bug_id}{$METADATA_DATE_BUGGY} = $project->{_vcs}->rev_date($results{$bug_id}{$BUGS_CSV_COMMIT_BUGGY});
        }
    }

    if (grep $_ eq $METADATA_DATE_FIXED, @requested) {
        foreach my $bug_id (keys %results) {
            $results{$bug_id}{$METADATA_DATE_FIXED} = $project->{_vcs}->rev_date($results{$bug_id}{$BUGS_CSV_COMMIT_FIXED});
        }
    }

    return %results;
}

=pod

=back

=cut

################################################################################

=pod

=head2 Internal Helper Subroutines

=over 4

=item C<Query::_read_bug_csv(filename, requested_fields)>

Gathers requested data from a designated bugs CSV file.
Returns a hash RESULTS [bug_id] = DATA [field] [value]
That is, we associate fields with their respective bug_id. 
Arguments: filename of bugs CSV file, a set of requested fields.

=cut

sub _read_bug_csv {
    my ($filename, @fields) = @_; 
    open (IN, "<$filename") or die "Cannot open $filename";
  
    my $head = <IN>;
    chomp $head;
    my @header = split /,/, $head;
    my %cols;
    my %results;

    my ($bug_id_col) = grep { $header[$_] eq $BUGS_CSV_BUGID } (0 .. @header-1);
    unless (defined $bug_id_col) {
        die "Bug IDs are not included in $filename.";
    }
   
    # Associate fields with columns using the header
    foreach my $item (@fields) {
        ($cols{$item}) = grep { $header[$_] eq $item } (0 .. @header -1);
        unless (defined $cols{$item}) {
            $cols{$item} = -1;
        }
    }

    # Read contents of file, associate each line with the bug ID.
    while (my $line = <IN>) {
        chomp $line;
        my @columns = split /,/, $line;
        my $bug_id = $columns[$bug_id_col];
        foreach my $item (@fields) {
            if ($cols{$item} != -1) {
                $results{$bug_id}{$item} = $columns[$cols{$item}];
            } else {
                $results{$bug_id}{$item} = "NA";
            }
        }
    }
    close IN;

    return %results;
}

=pod 

=item C<Query::_read_class_list(base_directory, file_extension, bug_ids)>

Reads in a class list (loaded/modified classes, relevant tests)
and returns the results as a single string, associated with
the requested bug IDs.

=cut

sub _read_class_list {
    my ($base_dir, $ext, @bugs) = @_; 
    my %results;

    foreach my $bug_id (@bugs) {
        my $filename = "$PROJECTS_DIR/$base_dir/$bug_id$ext";
        open (IN, "<$filename") or die "Cannot open $filename";
        my $list = <IN>;
        chomp $list;

        # Read contents of file
        while (my $line = <IN>) {
            chomp $line;
            $list = $list.";".$line;
        }
        close IN;
        $results{$bug_id} = "\"".$list."\"";
    }
    return %results;
}

=pod 

=item C<Query::_read_stack_traces(include_root, base_directory, bug_ids)>

Reads in a list of tests and stack traces (trigger/failing tests)
and returns the results as a single string, associated with
the requested bug IDs. The first argument determines whether
the root cause is included or not.

=back

=cut

sub _read_stack_traces {
    my ($include_root, $base_dir, @bugs) = @_; 
    my %results;

    foreach my $bug_id (@bugs) {
        my $filename = "$PROJECTS_DIR/$base_dir/$bug_id";
        open (IN, "<$filename") or die "Cannot open $filename";
        my $list = "";
        my $cause = 0;

        # Read contents of file
        while (my $line = <IN>) {
            chomp $line;
            if (grep /^--- /, $line) {
                $line =~ s/^--- //; 
                if ($list eq "") {
                    $list = $line;
                } else {
                    $list = $list.";".$line;
                }
                $cause = 1;
                next;
            }
            if ($cause == 1){
                $cause = 0;
                if ($include_root == 1){
                    $line =~ s/\"//g;
                    $list = $list." --> $line";
                }
            }
        }
        close IN;
        $results{$bug_id} = "\"".$list."\"";
    }
    return %results;
}

1;
