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

FaultLocalization.pm -- helper subroutines for fault localization analysis.

=head1 DESCRIPTION

This module provides helper subroutines for fault localization analysis using GZoltar.

=cut
package FaultLocalization;

use warnings;
use strict;

use Constants;
use Utils;
use DB;

use Getopt::Long;
use List::Util qw(sum);
use POSIX qw(ceil);

# Cache column names for table fault localization
my @COLS = DB::get_tab_columns($TAB_FAULT_LOCALIZATION) or die "Cannot obtain table columns!";

# Default paths
our $SER_FILE = "gzoltar.ser";
our $REPORT_FORMAT = "txt";
our $RANKING_EXTENSION_NAME = "ranking.csv";

# Instrumentation granularity level
our @GRANULARITY_LEVEL = ("line", "method", "class");

# Fault localization family techniques
our @FL_FAMILIES = ("sfl");

# Fault localization formulas
our @FL_FORMULAS = ("anderberg", "barinel", "dstar", "ideal", "jaccard", "kulczynski2",
                    "naish1", "ochiai", "ochiai2", "opt", "rogerstanimoto", "russelrao",
                    "sbi", "simplematching", "sorensendice", "tarantula");

# Path to java utility program
my $LOCS_TO_STMS_JAR = "$SCRIPT_DIR/lib/fault_localization/locs-to-stms-current.jar";
-e $LOCS_TO_STMS_JAR or die "File '$LOCS_TO_STMS_JAR' does not exist!";

# Path to the python script responsible to create a list of source code lines with suspiciousness values.
# The suspiciousness value of each line of code is extracted from its statement
my $STMT_SUSP_TO_LOC_SUSP_SCRIPT = "$SCRIPT_DIR/util/statement-suspiciousness-to-source_code_line-suspiciousness.py";
-e $STMT_SUSP_TO_LOC_SUSP_SCRIPT or die "File '$STMT_SUSP_TO_LOC_SUSP_SCRIPT' does not exist!";

=pod

=head2 Static subroutines

  FaultLocalization::diagnose(project, bug_id, instrument_classes_file, family, formulas, granularity, log_file, [all_tests, single_test])

Run fault localization analysis for a provided L<Project> reference and C<bug id>.

F<instrument_classes_file> is the name of a file that lists all the classes which should
be instrumented. C<family> defines the fault localization family technique, C<formulas>
defines the fault localization formulas, and C<granularity> defines the level of
instrumentation.

The test results are written to F<log_file>, and the boolean parameter C<all_tests>
indicates whether all test cases are executed. If not specified only relevant test cases
are executed. If C<single_test> is specified, only that test is executed. Format of
C<single_test>: <classname>::<methodname>.

=cut
sub diagnose {
    @_ >= 7 or die $ARG_ERROR;
    my ($project, $bug_id, $instrument_classes_file, $family, $formulas, $granularity, $log_file, $all_tests, $single_test) = @_;

    # Run unit test cases and collect coverage
    $project->fl_collect_coverage($instrument_classes_file, $log_file, $all_tests, $single_test) or return undef;

    # Perform fault localization analysis and parse the results
    return (_score($project, $bug_id, $instrument_classes_file, $family, $formulas, $granularity, $log_file));
}

=pod

  FaultLocalization::diagnose_ext(project, bug_id, instrument_classes, family, formulas, granularity, test_dir, log_file, [single_test])

Runs fault localization analysis for external (e.g., generated) test suites on the
provided L<Project> reference and C<bug id>.

F<instrument_classes> is the name of a file that lists all the classes which should be
instrumented. C<family> defines the fault localization family technique, C<formulas>
defines the fault localization formulas, and C<granularity> defines the level of
instrumentation.

C<test_dir> provides the root directory of the test cases to run, and the test results
are written to F<log_file>. If C<single_test> is specified, only that test is executed.
Format of C<single_test>: <classname>::<methodname>.

=cut
sub diagnose_ext {
    @_ >= 8 or die $ARG_ERROR;
    my ($project, $bug_id, $instrument_classes_file, $family, $formulas, $granularity, $test_dir, $include, $log_file, $single_test) = @_;

    # Run offline instrumentation
    $project->fl_instrument($instrument_classes_file, $log_file) or return undef;

    # Run unit test cases and collect coverage
    $project->run_ext_tests($test_dir, $include, $log_file, $single_test) or die "Could not run external test suite";

    # Perform fault localization analysis and parse the results
    return (_score($project, $bug_id, $instrument_classes_file, $family, $formulas, $granularity, $log_file));
}

=pod

  FaultLocalization::insert_row(hashref, [out_dir])

Insert a row into the database table L<TAB_FAULT_LOCALIZATION|DB>. C<hashref> points to a
hash holding all key-value pairs of the data row.  F<out_dir> is the optional alternative
database directory to use.

=cut
sub insert_row {
    my ($data, $out_dir) = @_;

    # Get proper output db handle: check whether a different output directory is provided
    my $dbh;
    if (defined $out_dir) {
        $dbh = DB::get_db_handle($TAB_FAULT_LOCALIZATION, $out_dir);
    } else {
        $dbh = DB::get_db_handle($TAB_FAULT_LOCALIZATION);
    }

    my @tmp;
    foreach (@COLS) {
        push (@tmp, $dbh->quote((defined $data->{$_} ? $data->{$_} : "-")));
    }

    my $row = join(",", @tmp);
    $dbh->do("INSERT INTO $TAB_FAULT_LOCALIZATION VALUES ($row)");
}

=pod

  FaultLocalization::copy_fault_localization_data(project, vid, suite, test_id, family, log_dir)

Copies the generated data files to a permanent directory F<log_dir>. C<project>
is the reference to a L<Project>, C<vid> is the version id, C<suite> specifies
the suite tag (e.g., manual, randoop, evosuite-branch), C<test_id> provides the
id of the test suite, and C<family> defines the fault localization family technique.

=cut
sub copy_fault_localization_data {
    my ($project, $vid, $suite, $test_id, $family, $log_dir) = @_;

    system("cp $project->{prog_root}/$SER_FILE $log_dir/$suite/$vid.$test_id.$SER_FILE") == 0 or die "Cannot copy '$SER_FILE' file";

    my $family_dir = "$log_dir/$suite/$vid.$test_id.$family";
    system("mkdir $family_dir") == 0 or die "Cannot create '$family_dir' directory";
    system("cp -R $project->{prog_root}/$family/* $family_dir/") == 0 or die "Cannot recursively copy the content of directory '$project->{prog_root}/$family/'";
}

#
# Simple helper subroutine to perform fault localization analysis and parse the results.
#
sub _score {
    my ($project, $bug_id, $instrument_classes_file, $family, $formulas, $granularity, $log_file) = @_;

    my $source_code_lines_file = _generate_source_code_lines_file($project->{prog_root}, $project->src_dir($bug_id . "b"), $instrument_classes_file, $log_file);
    my @all_scores = ();
    for my $formula(split /:/, $formulas) {
        # Run fault localization analysis
        $project->fl_analysis($granularity, $family, $formula, $log_file) or return undef;

        if ($granularity ne $GRANULARITY_LEVEL[0]) {
            print(STDERR "WARNING: Scoring system of fault localization analysis can only be performed with granularity level 'line'!\n");
            next;
        }

        # Run score system
        my $scores = _get_info_from_csv($project, $bug_id, $family, $formula, $source_code_lines_file, $log_file);
        if (defined $scores) {
            $scores->{$FL_FAMILY} = $family;
            $scores->{$FL_FORMULA} = $formula;

            push(@all_scores, $scores);
        }
    }

    return (@all_scores);
}

#
# Parse fault localization results file and return reference to a hash that holds all
# results.
#
sub _get_info_from_csv {
    my ($project, $bug_id, $family, $formula, $source_code_lines_file, $log_file) = @_;

    my $work_dir = $project->{prog_root};
    my $pid = $project->{pid};

    my $stmt_ranking_file = "$work_dir/$family/$REPORT_FORMAT/$formula.$RANKING_EXTENSION_NAME";
    -e $stmt_ranking_file or die "File '$stmt_ranking_file' does not exist";

    # Convert code statements to source code lines
    my $line_ranking_file = "$work_dir/$family/$REPORT_FORMAT/line.$formula.$RANKING_EXTENSION_NAME";
    my $cmd = "python $STMT_SUSP_TO_LOC_SUSP_SCRIPT " .
                "--stmt-susps-file $stmt_ranking_file " .
                "--source-code-lines-file $source_code_lines_file " .
                "--output-file $line_ranking_file >> $log_file 2>&1";
    Utils::exec_cmd($cmd, "Coverting code statements to source code lines") || die "Conversion of code statements to source code lines has failed!";
    -e $line_ranking_file or die "File '$line_ranking_file' does not exist";

    return _score_ranking($pid, $bug_id, $line_ranking_file);
}

#
# Given a ranking of suspicious source code lines, a list of buggy code lines this script
# determines the fraction of source code that needs to be examined before a buggy line or
# all buggy lines are found
#
sub _score_ranking {
    my ($pid, $bid, $ranking_file) = @_;
    -e $ranking_file or die "Fault localization results file does not exist: $ranking_file!";

    my $buggy_lines_file = "$SCRIPT_DIR/projects/$pid/buggy_lines/$bid.buggy.lines";
    -e $buggy_lines_file or die "File '$buggy_lines_file' does not exist!";

    my $sloc_file = "$SCRIPT_DIR/projects/$pid/slocs/$bid.sloc";
    -e $sloc_file or die "File '$sloc_file' does not exist!";

    # Determine lines of code for all loaded classes and all classes
    my $sloc = `tail -n1 $sloc_file`;
    $sloc =~ /^(\d+),(\d+)$/ or die "Unexpected format of sloc csv file!";
    my $sloc_loaded = $1;
    my $sloc_all = $2;

    # Cache the mapping from line to suspiciousness value
    my %ranks = ();
    open(IN, "<$ranking_file");
    while(<IN>) {
        # Skip header if it exists
        /Line,Suspiciousness/ and next;
        chomp;
        # e.g., org/jfree/chart/plot/CategoryPlot.java#1363,0.20851441405707477
        /([^#]+#\d+),(.+)/ or die "Unexpected line in ranking file: $_";
        $ranks{$1}={susp => $2};
    }
    close(IN);
    my $lines_ranking = scalar(keys(%ranks));

    # Sort by suspiciousness and store the rank for each file#line.
    # Traverse ranking from the smallest to the largest suspiciousness score and
    # assign the mean rank to all lines that have the same suspiciousness score.
    my @keys = sort { $ranks{$a}->{susp} <=> $ranks{$b}->{susp} } keys(%ranks);
    my $index = scalar(@keys);
    my $prev_susp = undef;
    my @ties;
    my $start;
    for (@keys) {
        if (defined($prev_susp) and $ranks{$_}->{susp} == $prev_susp) {
            # Still the same suspiciousness score -> add key to all tied statements
            push(@ties, $_);
        } else {
            # If this is not the lowest rank (very first key), compute average rank and assign
            # it to all tied statements
            if (defined($prev_susp)) {
                my $avg = ($start + $index + 1) / 2;
                foreach my $key(@ties) {
                    $ranks{$key}->{rank} = $avg;
                }
            }
            $prev_susp = $ranks{$_}->{susp};
            # Re-init set of tied statements, add current key, and store the current index as
            # start index
            @ties = ();
            push(@ties, $_);
            $start = $index;
        }
        --$index;
    }
    # Set ranking for the very last (or all tied) key(s)
    my $avg = ($start + $index + 1) / 2;
    foreach my $key(@ties) {
        $ranks{$key}->{rank} = $avg;
    }

    # Determine the rank for each buggy line and the overall min and max rank
    my @ranks_buggy_lines = ();
    open(IN, "<$buggy_lines_file");
    while(<IN>) {
        chomp;
        /([^#]+#\d+)#(.*)/ or die "Unexpected line in buggy lines file: $_";
        my $key = $1;
        my $type = $2;

        # Print a warning for buggy lines that are non-executable
        if ($type =~ /^\s*$/) {
            print(STDERR "WARNING: Non-executable line ($key) found in buggy lines file!\n");
        }
        if ($type =~ /^\s*\/\//) {
            print(STDERR "WARNING: Non-executable line ($key) found in buggy lines file!\n");
        }

        # Print a warning for buggy lines declared as unrankable
        if (_is_unrankable($key, $buggy_lines_file)) {
            print(STDERR "WARNING: Unrankable line ($key) found in buggy lines file!\n");
        }

        my $current_rank;
        # For faults of omission, check all candidates and take the min
        if ($type eq "FAULT_OF_OMISSION") {
            my @candidates = _get_candidates($key, $buggy_lines_file);

            my @cand_ranks = ();
            foreach (@candidates) {
                push(@cand_ranks, _get_rank($_, %ranks));
            }
            # Determine the minimum rank for all candidate ranks
            $current_rank = _get_min_rank(@cand_ranks);
            # Ranking does not contain any candidate line
            if (scalar(@cand_ranks) > 0 && $current_rank < 0) {
                print(STDERR "WARNING: Fault of omission ($key) not found in ranking! None of the candidate lines matches!\n");
            }
        } else {
            $current_rank = _get_rank($key, %ranks);
            # Ranking does not contain buggy line -> try candidates
            unless ($current_rank > 0) {
                my @candidates = _get_candidates($key, $buggy_lines_file);

                my @cand_ranks = ();
                foreach (@candidates) {
                    push(@cand_ranks, _get_rank($_, %ranks));
                }
                # Determine the minimum rank for all candidate ranks
                $current_rank = _get_min_rank(@cand_ranks);
                # Ranking does not contain any candidate line -> print error message and continue
                if (scalar(@cand_ranks) > 0 && $current_rank < 0) {
                    print(STDERR "WARNING: Fault ($key) not found in ranking! None of the candidate lines matches!\n");
                }
            }
        }
        # Special handling for unranked (NA) lines. For instance, for Chart-23b, Lang-23b, Lang-29b, or Lang-56b
        # there is not any candidate for the single unranked line. The rank for every NA line is:
        #     lines_ranking + (sloc(loaded_classes) - lines_ranking) / 2
        if ($current_rank < 0) {
            $current_rank = $lines_ranking + ($sloc_loaded - $lines_ranking) / 2;
        }

        # Add current rank to list of ranks for all buggy lines
        push(@ranks_buggy_lines, $current_rank);
    }

    # Sort the list of all ranks, and determine min, max, mean, median if there is a list of lines
    # to rank
    @ranks_buggy_lines = sort { $a <=> $b } @ranks_buggy_lines;
    my $min    = $ranks_buggy_lines[0];
    my $max    = $ranks_buggy_lines[-1];
    my $mean   = _get_mean(@ranks_buggy_lines);
    my $median = _get_median_sorted(@ranks_buggy_lines);

    # Compute overall score considering the set of classes (loaded classes vs. all
    # classes) and return hash reference
    return {
        $MIN_SCORE_LOADED_CLASSES => $min / $sloc_loaded,
        $MAX_SCORE_LOADED_CLASSES => $max / $sloc_loaded,
        $MEAN_SCORE_LOADED_CLASSES => $mean / $sloc_loaded,
        $MEDIAN_SCORE_LOADED_CLASSES => $median / $sloc_loaded,

        $MIN_SCORE_ALL_CLASSES => $min / $sloc_all,
        $MAX_SCORE_ALL_CLASSES => $max / $sloc_all,
        $MEAN_SCORE_ALL_CLASSES => $mean / $sloc_all,
        $MEDIAN_SCORE_ALL_CLASSES => $median / $sloc_all,
    };
}

#
# Get the ranking for a particular line
#
# Returns -1 if the ranking doesn't contain the line
#
sub _get_rank {
    my ($key, %ranks) = @_;

    unless (defined $ranks{$key}) {
        return -1;
    }
    return $ranks{$key}->{rank};
}

#
# Determine the minimum rank of an array.
#
# Returns the minimum rank or -1 of none of the ranks is valid.
#
sub _get_min_rank {
    my @array = @_;
    my $min = -1;
    for my $rank(@array) {
        $rank != -1 or next;
        if ($min == -1 or $rank < $min) {
            $min = $rank;
        }
    }
    return $min;
}

#
# Returns true if a given buggy line is unrankable, false otherwise.
#
# This routine lazily caches all unrankable lines for a given bug, using the
# following hash (%unrankable_lines):
# {file1#line_unrankable1 => 1,
#  file1#line_unrankable2 => 1,
#  file2#line_unrankable1 => 1}
# ...
#
my %unrankable_lines = ("init" => 0);
sub _is_unrankable {
    my ($key, $buggy_lines_file) = @_;

    unless ($unrankable_lines{"init"}) {
        $unrankable_lines{"init"} = 1;
        $buggy_lines_file =~ /^(.+)\.buggy\.lines/ or die "Unexpected file name of buggy lines: $buggy_lines_file";
        my $unrankable = "$1.unrankable.lines";
        unless (-e $unrankable) {
            return 0;
        }
        open(RANK, "<$unrankable") or die "Cannot read unrankable lines file: $unrankable";
        while(<RANK>) {
            /^([^#]+#\d+)#(.+)$/ or die "Unexpected format in unrankable lines file!";
            $unrankable_lines{$1}=1;
        }
        close(RANK);
    }
    return defined($unrankable_lines{$key});
}

#
# Returns an array of candidate lines for a fault of omission.
# Lazily cache all candidate lines, using the following representation:
#
# {file1#line_fault1} -> {file#line_candidate1 => 1,
#                         file#line_candidate2 => 1,
#                         file#line_candidate3 => 1}
#
# {file1#line_fault2} -> {file#line_candidate1 => 1}
#
# {file2#line_fault1} -> {file#line_candidate1 => 1}
# ...
#
my %all_candidates = ();
sub _get_candidates {
    my ($key, $buggy_lines_file) = @_;

    unless (defined $all_candidates{$key}) {
        $buggy_lines_file =~ /^(.+)\.buggy\.lines/ or die "Unexpected file name of buggy lines: $buggy_lines_file";
        my $candidates = "$1.candidates";
        unless (-e $candidates) {
            return ();
        }
        open(CAND, "<$candidates") or die "Cannot read candidates file: $candidates";
        while(<CAND>) {
            /^([^,]+),(.+)$/ or die "Unexpected format in candidates file!";
            $all_candidates{$1}->{$2}=1;
        }
        close(CAND);
    }
    #die unless defined $all_candidates{$key};
    return keys %{$all_candidates{$key}};
}

#
# Simple helper subroutine to compete the median in a sorted array.
#
sub _get_median_sorted {
    return sum(@_[int($#_/2), ceil($#_/2)])/2;
}

#
# Simple helper subroutine to compete the mean in an array.
#
sub _get_mean {
    return (sum(@_) / scalar(@_));
}

#
# Converts a list of class names (extracted from F<classes_file>) into a single string.
# In the returned string each class name is separated by C<separator>.
#
# <include_inner_classes> and <local_file_representation> are optional parameters.If
# <include_inner_classes> is enabled, the returned string also includes a wilcard to
# handle Java inner classes. I.e., for each "org.foo.Bar" an additional "org.foo.Bar$*"
# is also included in the returned string. If <local_file_representation> is enabled,
# each class name is represented by '/' rather than by '.', and '.class' is appended at
# the end of the class name, e.g., "org/foo/Bar.class"" instead of just "org.foo.Bar".
#
sub _list_of_classes_to_string {
    my ($classes_file, $separator, $include_inner_classes, $local_file_representation) = @_;

    -e $classes_file or die "Classes file '$classes_file' does not exist!";
    open(FH, "<$classes_file") or die "Cannot open classes file '$classes_file'";
    chomp(my @classes = <FH>);
    close(FH);

    die "No classes found!" if scalar @classes == 0;

    my $file_extension = "";
    if (defined $local_file_representation && $local_file_representation) {
      $file_extension = ".class";
    }

    if (defined $include_inner_classes && $include_inner_classes) {
        # Augment list of classes with inner classes
        die "No classes found!" if scalar @classes == 0;
        my @classes_and_inners = ();
        for (@classes) {
            if (defined $local_file_representation && $local_file_representation) {
              s/\./\//g;
            }
            chomp;
            push @classes_and_inners, "$_" . "$file_extension";
            push @classes_and_inners, "$_" . '\$' . "*" . "$file_extension";
        }
        # Create a single string with all classes and inner classes separated by the defined separator
        return (join($separator, @classes_and_inners));
    }

    # Create a single string with all classes separated by the defined separator
    return (join($separator, @classes));
}

#
# Create a list of source code lines for the checkout project.
#
sub _generate_source_code_lines_file {
    my ($work_dir, $src_dir, $instrument_classes_file, $log_file) = @_;

    my $list_of_classes = _list_of_classes_to_string($instrument_classes_file, " ");
    my $source_code_lines_file = "$work_dir/source_code_lines.txt";
    my $cmd = "cd $work_dir" .
              " && java -jar $LOCS_TO_STMS_JAR locstostms " .
                "$list_of_classes " .
                "--srcDirs $src_dir " .
                "--outputFile $source_code_lines_file >> $log_file 2>&1";
    Utils::exec_cmd($cmd, "Collecting source code lines") || die "locstostms has failed!";
    -e $source_code_lines_file or die "File '$source_code_lines_file' does not exist!";

    return ($source_code_lines_file);
}

1;
