#-------------------------------------------------------------------------------
# Copyright (c) 2014-2017 René Just, Darioush Jalali, and Defects4J contributors.
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

Mutation.pm -- helper subroutines for mutation analysis.

=head1 DESCRIPTION

This module provides helper subroutines for mutation analysis using the Major
mutation framework.

=cut
package Mutation;

use warnings;
use strict;

use Constants;
use DB;

# Cache column names for table mutation
my @COLS = DB::get_tab_columns($TAB_MUTATION) or die "Cannot obtain table columns!";

# Name of file that holds all mutants to exclude from analysis
my $EXCL_FILE = "exclude.txt";
# Name of file that provides kill details for mutants
my $KILL_FILE = "kill.csv";
# Name of file that provides a summary of the mutation analysis results
my $SUMMARY_FILE = "summary.csv";

=pod

=head2 Static subroutines

  Mutation::mutation_analysis(project_ref, log_file [, base_map, single_test])

Runs mutation analysis for the developer-written test suites of the provided
L<Project> reference.  Returns a reference to a hash that provides kill details
for all covered mutants:

=over 4

  {mut_id} => "[TIME|EXC|FAIL|LIVE]"

=back

=cut
sub mutation_analysis {
    @_ >= 2 or die $ARG_ERROR;
    my ($project, $log_file, $base_map, $single_test) = @_;

    # If base_map is defined, exclude all already killed mutants from analysis
    if (defined $base_map) {
        _exclude_mutants($project, $base_map)
    }

    if (! $project->mutation_analysis($log_file, $single_test)) {
        return undef;
    }

    return _build_mut_map($project, $base_map);
}


=pod

  Mutation::mutation_analysis_ext(project_ref, test_dir, include, log_file [, base_map])

Runs mutation analysis for external (e.g., generated) test suites on the
provided L<Project> reference. Returns a reference to a hash that provides kill
details for all covered mutants:

=over 4

  {mut_id} => "[TIME|EXC|FAIL|LIVE]"

=back

=cut
sub mutation_analysis_ext {
    @_ >= 4 or die $ARG_ERROR;
    my ($project, $test_dir, $include, $log_file, $base_map) = @_;

    # If base_map is defined, exclude all already killed mutants from analysis
    if (defined $base_map) {
        _exclude_mutants($project, $base_map)
    }

    if (! $project->mutation_analysis_ext($test_dir, $include, $log_file)) {
        return undef;
    }

    return _build_mut_map($project, $base_map);
}


=pod

  Mutation::insert_row(output_dir, pid, vid, suite_src, tid, gen [, mutation_map])

Insert a row into the database table L<TAB_MUTATION|DB>. C<hashref> points to a
hash holding all key-value pairs of the data row.  F<out_dir> is the optional
alternative database directory to use.

=cut
sub insert_row {
    @_ >= 5 or die $ARG_ERROR;
    my ($out_dir, $pid, $vid, $suite, $test_id, $gen, $mut_map) = @_;

    # Build data hash
    my $data = _build_data_hash($pid, $vid, $suite, $test_id, $gen, $mut_map);

    # Get proper output db handle: check whether a different output directory is provided
    my $dbh;
    if (defined $out_dir) {
        $dbh = DB::get_db_handle($TAB_MUTATION, $out_dir);
    } else {
        $dbh = DB::get_db_handle($TAB_MUTATION);
    }

    # Build row based on data hash
    my @tmp;
    foreach (@COLS) {
        push (@tmp, $dbh->quote((defined $data->{$_} ? $data->{$_} : "-")));
    }

    # Concat values and write to database table
    my $row = join(",", @tmp);

    $dbh->do("INSERT INTO $TAB_MUTATION VALUES ($row)");
    $dbh->disconnect();
}

=pod

  Mutation::copy_mutation_logs(project, vid, suite, test_id, log, log_dir)

Copies the mutation log files to a permanent directory F<log_dir>.  C<project>
is the reference to a L<Project>, C<vid> is the version id, C<suite> specifies
the suite tag (e.g., manual, randoop, evosuite-branch), and C<test_id> provides
the id of the test suite. TODO

=cut
sub copy_mutation_logs {
    @_ == 6 or die $ARG_ERROR;
    my ($project, $vid, $suite, $test_id, $log, $log_dir) = @_;
    # Copy mutation log files to log directory
    system("cp $project->{prog_root}/mutants.log $log_dir/$suite/$vid.mutants.log") == 0
        or  die "Cannot copy mutants.log file";
    system("cp $log $log_dir/$suite/$vid.$test_id.log") == 0
        or die "Cannot copy mutation analysis log file";
    # The file that summarizes the results is only generated upon success
    if (-e "$project->{prog_root}/$SUMMARY_FILE") {
        system("cp $project->{prog_root}/$SUMMARY_FILE $log_dir/$suite/$vid.$test_id.$SUMMARY_FILE") == 0
            or die "Cannot copy mutation analysis result file";
    }
    # The file with the kill details is only generated for strong mutation
    if (-e "$project->{prog_root}/$KILL_FILE") {
        system("cp $project->{prog_root}/$KILL_FILE $log_dir/$suite/$vid.$test_id.$KILL_FILE") == 0
            or die "Cannot copy $KILL_FILE!";
    }
}


#
# Parse kill details file and build mutant map
#
sub _build_mut_map {
    my ($project, $base_map) = @_;

    my $mut_map = {};
    open(IN, "<$project->{prog_root}/$KILL_FILE") or die "Cannot open kill details!";
    # Skip header
    $_ = <IN>;
    while(<IN>) {
        chomp;
        /(\d+),(TIME|EXC|FAIL|LIVE)/ or die "Wrong format of kill details file";
        $mut_map->{$1}=$2;
    }
    close(IN);

    # Merge mutation results if base_map exists
    if (defined $base_map) {
        foreach my $mut_id (keys %{$base_map}) {
            next if defined $mut_map->{$mut_id};
            $mut_map->{$mut_id} = $base_map->{$mut_id};
        }
    }
    return $mut_map;
}


#
# Write already killed mutants to exclude file
#
sub _exclude_mutants {
    @_ == 2 or die $ARG_ERROR;
    my ($project, $mut_map) = @_;

    open(OUT, ">$project->{prog_root}/$EXCL_FILE") or die "Cannot open exclude file!";
    foreach my $mut_id (keys %{$mut_map}) {
        next if ($mut_map->{$mut_id} eq "LIVE");
        print OUT "$mut_id\n";
    }
    close(OUT);
}


#
# Determines number of covered and killed mutants and builds the data hash.
# Returns a reference to a hash that holds all results.
#
sub _build_data_hash {
    @_ >= 5 or die $ARG_ERROR;
    my ($pid, $vid, $suite, $test_id, $gen, $mut_map) = @_;

    my $cov;
    my $kill;
    if (defined $mut_map) {
        $cov = scalar(keys %{$mut_map});
        $kill = 0;
        foreach my $mut_id (keys %{$mut_map}) {
            next if $mut_map->{$mut_id} =~ /LIVE/;
            ++$kill;
        }
    }

    # Set all values and return hash reference
    return {
        $PROJECT => $pid,
        $ID => $vid,
        $TEST_SUITE => $suite,
        $TEST_ID => $test_id,
        $MUT_GEN => $gen,
        $MUT_COV => $cov,
        $MUT_KILL => $kill,
    };
}

1;
