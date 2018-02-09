#!/usr/bin/env perl
#
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

analyze-project.pl -- Determine all suitable candidates listed in the commit-db.

=head1 SYNOPSIS

analyze-project.pl -p project_id -w work_dir [ -b bug_id]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the project for which the version pairs are analyzed.

=item B<-w C<work_dir>>

Use C<work_dir> as the working directory.

=item B<-b C<bug_id>>

Only analyze this bug id or interval of bug ids (optional).
The bug_id has to have the format B<(\d+)(:(\d+))?> -- if an interval is
provided, the interval boundaries are included in the analysis.
Per default all bug ids, listed in the commit-db, are considered.

=back

=head1 DESCRIPTION

Runs the following worflow for all candidate bugs in the project's
C<commit-db>, or (if -b is specified) for a subset of candidates:


=over 4

=item 1) Verify that src diff (between pre-fix and post-fix) is not empty.

=item 3) Checkout fixed revision

=item 4) Compile src and test

=item 5) Run tests and log failing tests to F<C<PROJECTS_DIR>/<PID>/failing_tests>

=item 6) Exclude failing tests, recompile and rerun. This will be repeated until there are
         no more failing tests in F<$TEST_RUNS> consecutive executions.
         (Maximum limit of looping in this phase is specified by F<$MAX_TEST_RUNS>)

=item 6) Checkout fixed version

=item 7) Apply src patch (fixed -> buggy)

=item 8) Compile src and test

=back

The result for each individual step is stored in F<C<work_dir>/$TAB_REV_PAIRS>

For each steps the output table contains a column, indicating the result of the
the step or '-' if the step was not applicable.

=cut

use warnings;
use strict;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;
use Carp qw(confess);

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;
use Project;
use DB;
use Utils;

############################## ARGUMENT PARSING
my %cmd_opts;
getopts('p:b:w:', \%cmd_opts) or pod2usage(1);

my ($PID, $BID, $WORK_DIR) =
    ($cmd_opts{p},
     $cmd_opts{b},
     $cmd_opts{w}
    );

pod2usage(1) unless defined $PID and defined $WORK_DIR; # $BID can be undefined

$WORK_DIR = abs_path($WORK_DIR);

# Add script and core directory to @INC
unshift(@INC, "$WORK_DIR/framework/core");

# Set the projects and repository directories to the current working directory.
$PROJECTS_DIR = "$WORK_DIR/framework/projects";
$REPO_DIR = "$WORK_DIR/project_repos";

my $PATCH_DIR   = "$PROJECTS_DIR/$PID/patches";
my $FAILING_DIR = "$PROJECTS_DIR/$PID/failing_tests";

# TODO make output dir more flexible; maybe organize the csv-based db differently
my $db_dir = $WORK_DIR;

# Check format of target version id
if (defined $BID) {
    $BID =~ /^(\d+)(:(\d+))?$/ or die "Wrong version id format ((\\d+)(:(\\d+))?): $BID!";
}

############################### VARIABLE SETUP
# Number of successful test runs in a row required
my $TEST_RUNS=2;
# Number of maximum test runs (give up point)
my $MAX_TEST_RUNS=10;

# Temporary directory
my $TMP_DIR = Utils::get_tmp_dir();
system("mkdir -p $TMP_DIR");
# Set up project
my $project = Project::create_project($PID);
$project->{prog_root} = $TMP_DIR;

# Get database handle for results
my $dbh = DB::get_db_handle($TAB_REV_PAIRS, $db_dir);
my @COLS = DB::get_tab_columns($TAB_REV_PAIRS) or die;

############################### MAIN LOOP
# figure out which IDs to run script for
my @ids = $project->get_version_ids();
if (defined $BID) {
    if ($BID =~ /(\d+):(\d+)/) {
        @ids = grep { ($1 <= $_) && ($_ <= $2) } @ids;
    } else {
        # single vid
        @ids = grep { ($BID == $_) } @ids;
    }
}

my $sth = $dbh->prepare("SELECT * FROM $TAB_REV_PAIRS WHERE $PROJECT=? AND $ID=?") or die $dbh->errstr;
foreach my $bid (@ids) {
    # Skip existing entries
    $sth->execute($PID, $bid);
    if($sth->rows !=0) {
        print "Skipping $bid because of existing entry in $TAB_REV_PAIRS\n";
        next;
    }


    printf ("%4d: $project->{prog_name}\n", $bid);

    my %data;
    $data{$PROJECT} = $PID;
    $data{$ID} = $bid;

    _check_diff($project, $bid, \%data) and
    _check_t2v2($project, $bid, \%data) and
    _check_t2v1($project, $bid, \%data);

    # Add data set to result file
    _add_row(\%data);
}
$dbh->disconnect();
system("rm -rf $TMP_DIR");

############################### SUBROUTINES
# Check size of src diff, which is created by initialize-revisions.pl, for a
# given candidate bug (bid).
#
# Returns 1 on success, 0 otherwise
sub _check_diff {
    my ($project, $bid, $data) = @_;

    # Determine patch size for src and test patches (rev2 -> rev1)
    my $patch_test = "$PATCH_DIR/$bid.test.patch";
    my $patch_src = "$PATCH_DIR/$bid.src.patch";

    if (-z $patch_test) {
        $data->{$DIFF_TEST} = 0;
    } else {
        my $diff = _read_file($patch_test);
        die unless defined $diff;
        $data->{$DIFF_TEST} = scalar(split("\n", $diff));
    }

    if (-z $patch_src) {
        $data->{$DIFF_SRC} = 0;
    } else {
        my $diff = _read_file($patch_src);
        die unless defined $diff;
        $data->{$DIFF_SRC} = scalar(split("\n", $diff)) or return 0;
    }

    return 1;
}

#
# Check whether v2 and t2 can be compiled and export failing tests.
#
# Returns 1 on success, 0 otherwise
sub _check_t2v2 {
    my ($project, $bid, $data) = @_;

    # Lookup revision ids
    my $v1  = $project->lookup("${bid}b");
    my $v2  = $project->lookup("${bid}f");

    # Checkout v2
    $project->checkout_vid("${bid}f", $TMP_DIR, 1) == 1 or die;

    # Compile v2 ant t2
    my $ret = $project->compile();
    _add_bool_result($data, $COMP_V2, $ret) or return 0;
    $ret = $project->compile_tests();
    _add_bool_result($data, $COMP_T2V2, $ret) or return 0;

    # Clean previous results
    ` >$FAILING_DIR/$v2` if -e "$FAILING_DIR/$v2";
    my $successful_runs = 0;
    my $run = 1;
    while ($successful_runs < $TEST_RUNS && $run <= $MAX_TEST_RUNS) {
        # Automatically fix broken tests and recompile
        $project->fix_tests("${bid}f");
        $project->compile_tests() or die;

        # Run t2 and get number of failing tests
        my $file = "$project->{prog_root}/v2.fail"; `>$file`;
        $project->run_tests($file) or die;
        # Get number of failing tests
        my $list = Utils::get_failing_tests($file);
        my $fail = scalar(@{$list->{"classes"}}) + scalar(@{$list->{"methods"}});

        if ($run == 1) {
            $data->{$FAIL_T2V2} = $fail;
        } else {
            $data->{$FAIL_T2V2} += $fail;
        }

        ++$successful_runs;

        # Append to log if there were (new) failing tests
        unless ($fail == 0) {
            open(OUT, ">>$FAILING_DIR/$v2") or die "Cannot write failing tests: $!";
            print OUT "## $project->{prog_name}: $v2 ##\n";
            close OUT;
            system("cat $file >> $FAILING_DIR/$v2");
            $successful_runs = 0;
        }
        ++$run;
    }
    return 1;
}

# Check whether t2 and v1 can be compiled
sub _check_t2v1 {
    my ($project, $bid, $data) = @_;

    # Lookup revision ids
    my $v1  = $project->lookup("${bid}b");
    my $v2  = $project->lookup("${bid}f");

    # Checkout v1
    $project->checkout_vid("${bid}b", $TMP_DIR, 1) == 1 or die;

    # Compile v1 and t2v1
    my $ret = $project->compile();
    _add_bool_result($data, $COMP_V1, $ret) or return;
    $ret = $project->compile_tests();
    _add_bool_result($data, $COMP_T2V1, $ret);
}

#
# Read a file line by line and return an array with all lines.
#
sub _read_file {
    my $fn = shift;
    open(FH, "<$fn") or confess "Could not open file: $!";
    my @lines = <FH>;
    close(FH);
    return join('', @lines);
}

#
# Insert boolean success into hash
#
sub _add_bool_result {
    my ($data, $key, $success) = @_;
    $data->{$key} = $success;
}

#
# Add a row to the database table
#
sub _add_row {
    my $data = shift;

    my @tmp;
    foreach (@COLS) {
        push (@tmp, $dbh->quote((defined $data->{$_} ? $data->{$_} : "-")));
    }

    my $row = join(",", @tmp);
    $dbh->do("INSERT INTO $TAB_REV_PAIRS VALUES ($row)");
}

=pod

=head1 SEE ALSO

All valid C<project_id>s are listed in F<Project.pm>
To achieve workflow, after this script manually verify that all test failures are valid
and not spurious, broken, random, or due to classpath issues.

Next step in workflow: F<get-trigger.pl>
=cut
