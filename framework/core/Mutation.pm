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
our $EXCL_FILE = "exclude.txt";
# Name of file that provides kill details for killed mutants
our $KILL_FILE = "kill.csv";
# Name of file that provides a summary of the mutation analysis results
our $SUMMARY_FILE = "summary.csv";
# Name of file that maps test IDs to test names
our $TEST_MAP_FILE = "testMap.csv";

=pod

=head2 Static subroutines

=over 4

=item C<Mutation::create_mml(instrument_classes, out_file, mut_ops)>

Generates an mml file, enabling all mutation operators defined by the array
reference C<mut_ops> for all classes listed in F<instrument_classes>. The mml
(source) file is written to C<out_file>. This subroutine also compiles the mml
file to F<'out_file'.bin>.

=cut

sub create_mml {
    @_ == 3 or die $ARG_ERROR;
    my ($instrument_classes, $out_file, $mut_ops) = @_;

    my $OUT_DIR = Utils::get_dir($out_file);
    my $TEMPLATE = `cat $UTIL_DIR/template.mml` or die "Cannot read mml template: $!";

    system("mkdir -p $OUT_DIR");

    open(IN, $instrument_classes);
    my @classes = <IN>;
    close(IN);

    # Generate mml file by enabling operators for listed classes only
    open(FILE, ">$out_file") or die "Cannot write mml file ($out_file): $!";
    # Add operator definitions from template
    print FILE $TEMPLATE;
    # Enable operators for all classes
    foreach my $class (@classes) {
        chomp $class;
        print FILE "\n// Enable operators for $class\n";
        foreach my $op (@{$mut_ops}) {
            # Skip disabled operators
            next if $TEMPLATE =~ /-$op<"$class">/;
            print FILE "$op<\"$class\">;\n";
        }
    }
    close(FILE);
    Utils::exec_cmd("$MAJOR_ROOT/bin/mmlc $out_file 2>&1", "Compiling mutant definition (mml)")
            or die "Cannot compile mml file: $out_file!";
}

=pod

=item C<Mutation::mutation_analysis(project_ref, log_file [, exclude_file, base_map, single_test])>

Runs mutation analysis for the developer-written test suites of the provided
L<Project> reference.  Returns a reference to a hash that provides kill details
for all covered mutants:
S<C<{mut_id} =E<gt> "[TIME|EXC|FAIL|LIVE]">>

=cut

sub mutation_analysis {
    @_ >= 3 or die $ARG_ERROR;
    my ($project, $log_file, $exclude_file, $base_map, $single_test) = @_;

    # If base_map is defined, exclude all already killed mutants (in addition to
    # the mutants defined in the exclude file) from the analysis.
    if (defined $base_map) {
        $exclude_file = _exclude_mutants($project, $exclude_file, $base_map)
    }

    if (! $project->mutation_analysis($log_file, 0, $exclude_file, $single_test)) {
        return undef;
    }

    return _build_mut_map($project, $base_map);
}

=pod

=item C<Mutation::mutation_analysis_ext(project_ref, test_dir, include, log_file [, exclude_file, base_map])>

Runs mutation analysis for external (e.g., generated) test suites on the
provided L<Project> reference. Returns a reference to a hash that provides kill
details for all covered mutants:
S<C<{mut_id} =E<gt> "[TIME|EXC|FAIL|LIVE]">>

=cut

sub mutation_analysis_ext {
    @_ >= 4 or die $ARG_ERROR;
    my ($project, $test_dir, $include, $log_file, $exclude_file, $base_map) = @_;

    # If base_map is defined, exclude all already killed mutants (in addition to
    # the mutants defined in the exclude file) from the analysis.
    if (defined $base_map) {
        $exclude_file = _exclude_mutants($project, $exclude_file, $base_map)
    }

    if (! $project->mutation_analysis_ext($test_dir, $include, $log_file, $exclude_file)) {
        return undef;
    }

    return _build_mut_map($project, $base_map);
}

=pod

=item C<Mutation::parse_mutation_operators(file_name)>

Parses the provided text file and returns an array with mutation operator names
(i.e., "AOR", "ROR", etc.).

=cut

sub parse_mutation_operators {
    @_ == 1 or die $ARG_ERROR;
    my ($file_name) = @_;

    my @ops = ();

    open(IN, "<$file_name") or die "Cannot open mut-ops file ($file_name): $!";
    while(my $line = <IN>) {
        chomp($line);
        my @tmp = split(" ", $line);
        push(@ops, @tmp);
    }
    close(IN);

    return @ops;
}

=pod

=item C<Mutation::insert_row(output_dir, pid, vid, suite_src, tid, gen, num_excluded [, mutation_map])>

Insert a row into the database table L<TAB_MUTATION|DB>. C<hashref> points to a
hash holding all key-value pairs of the data row.  F<out_dir> is the optional
alternative database directory to use.

=cut

sub insert_row {
    @_ >= 5 or die $ARG_ERROR;
    my ($out_dir, $pid, $vid, $suite, $test_id, $gen, $num_excluded, $mut_map) = @_;

    # Build data hash
    my $data = _build_data_hash($pid, $vid, $suite, $test_id, $gen, $num_excluded, $mut_map);

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

=item C<Mutation::copy_mutation_logs(project, vid, suite, test_id, log, log_dir)>

Copies the mutation log files to a permanent directory F<log_dir>.  C<project>
is the reference to a L<Project>, C<vid> is the version id, C<suite> specifies
the suite tag (e.g., manual, randoop, evosuite-branch), and C<test_id> provides
the id of the test suite. TODO

=cut

sub copy_mutation_logs {
    @_ == 6 or die $ARG_ERROR;
    my ($project, $vid, $suite, $test_id, $log, $log_dir) = @_;
    # Copy the summary of generated mutants -- identical for all test IDs
    system("cp $project->{prog_root}/mutants.log $log_dir/$suite/$vid.mutants.log") == 0
        or  die "Cannot copy mutants.log file";
    # Copy the mutation analysis log file -- unique per test ID
    system("cp $log $log_dir/$suite/$vid.$test_id.log") == 0
        or die "Cannot copy mutation analysis log file";
    # Copy additional data files generated by Major -- unique per test ID
    for my $file ($SUMMARY_FILE, $KILL_FILE, $TEST_MAP_FILE) {
        if (-e "$project->{prog_root}/$SUMMARY_FILE") {
            system("cp $project->{prog_root}/$file $log_dir/$suite/$vid.$test_id.$file") == 0
                or die "Cannot copy mutation analysis data file: $file";
        }
    }
}

=pod

=back

=cut

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
        /(\d+),(TIME|EXC|FAIL|LIVE|UNCOV)/ or die "Wrong format of kill details file";
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
# Write the list of already killed mutants to a plain-text exclude file.
#
sub _exclude_mutants {
    @_ == 3 or die $ARG_ERROR;
    my ($project, $exclude_file, $mut_map) = @_;

    open(OUT, ">$project->{prog_root}/$EXCL_FILE") or die "Cannot open exclude file!";
    foreach my $mut_id (keys %{$mut_map}) {
        next if ($mut_map->{$mut_id} =~ "(LIVE|UNCOV)");
        print OUT "$mut_id\n";
    }

    if (defined $exclude_file) {
        # Add all mutants defined in the exclude file that are not already killed
        open(EXCL, "<$exclude_file") or die "Cannot read exclude file";
        while (<EXCL>) {
            next if /^\s*(#.*)?$/;
            /^\s*([0-9]+)/ or die "Unexpected line in exclude file!";
            my $mut_id = $1;
            next if (exists $mut_map->{$mut_id} && $mut_map->{mut_id} ne "LIVE");
            print OUT "$mut_id\n";
        }
        close(EXCL);
    }
    close(OUT);

    return "$project->{prog_root}/$EXCL_FILE";
}


#
# Determines number of covered and killed mutants and builds the data hash.
# Returns a reference to a hash that holds all results.
#
sub _build_data_hash {
    @_ >= 5 or die $ARG_ERROR;
    my ($pid, $vid, $suite, $test_id, $gen, $num_excluded, $mut_map) = @_;

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
        $MUT_EXCL => $num_excluded,
        $MUT_COV => $cov,
        $MUT_KILL => $kill,
    };
}

1;
