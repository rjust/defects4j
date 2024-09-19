#!/usr/bin/env perl
#
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

get-trigger.pl -- Determines triggering tests for all reviewed version pairs in
F<work_dir/$TAB_REV_PAIRS>, or a single version (or range).

=head1 SYNOPSIS

get-trigger.pl -p project_id -w work_dir [-b bug_id]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the project for which the meta data should be generated.

=item B<-w F<work_dir>>

The working directory used for the bug-mining process.

=item B<-b C<bug_id>>

Only analyze this bug id. The bug_id has to follow the format B<(\d+)(:(\d+))?>.
Per default all bug ids, listed in the active-bugs csv, are considered.

=head1 DESCRIPTION

Runs the following workflow for the project C<project_id> and the results are
written to F<work_dir/TAB_TRIGGER>. For all B<reviewed> version pairs in
F<work_dir/$TAB_REV_PAIRS>:

=over 4

=item 1) Checkout fixed version.

=item 2) Compile src and test.

=item 3) Run tests and verify that all tests pass.

=item 4) Checkout buggy version.

=item 5) Compile src and test.

=item 6) Run tests and verify that no test class fails and at least on test
         method fails (all failing test methods are B<individual triggering tests>).

=item 7) Run every triggering test in isolation on the fixed version and verify
         that it passes.

=item 8) Run every triggering test in isolation on the buggy verision and verify
         that it fails.

=item 9) Export triggering tests to F<C<work_dir>/<project_id>/trigger_tests>.

=back

The result for each individual step is stored in F<C<work_dir>/$TAB_TRIGGER>.
For each step the output table contains a column, indicating the result of the
step or '-' if the step was not applicable.

=cut
use warnings;
use strict;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;
use Project;
use DB;
use Utils;

my %cmd_opts;
getopts('p:b:w:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{w};

my $PID = $cmd_opts{p};
my $BID = $cmd_opts{b};
my $WORK_DIR = abs_path($cmd_opts{w});

# Check format of target bug id
if (defined $BID) {
    $BID =~ /^(\d+)(:(\d+))?$/ or die "Wrong version id format ((\\d+)(:(\\d+))?): $BID!";
}

# DB_CSVs directory
my $db_dir = $WORK_DIR;

# Add script and core directory to @INC
unshift(@INC, "$WORK_DIR/framework/core");

# Override global constants
$REPO_DIR = "$WORK_DIR/project_repos";
$PROJECTS_DIR = "$WORK_DIR/framework/projects";

# Set the projects and repository directories to the current working directory.
my $PROJECTS_DIR = "$WORK_DIR/framework/projects";

# Temporary directory
my $TMP_DIR = Utils::get_tmp_dir();
system("mkdir -p $TMP_DIR");

# Set up project
my $project = Project::create_project($PID);
$project->{prog_root} = $TMP_DIR;

# Get database handle for results
my $dbh_trigger = DB::get_db_handle($TAB_TRIGGER, $db_dir);
my $dbh_revs = DB::get_db_handle($TAB_REV_PAIRS, $db_dir);
my @COLS = DB::get_tab_columns($TAB_TRIGGER) or die;

# Set up directory for triggering tests
my $OUT_DIR = "$PROJECTS_DIR/$PID/trigger_tests";
system("mkdir -p $OUT_DIR");

# dependent tests saved to this file
my $DEP_TEST_FILE            = "$PROJECTS_DIR/$PID/dependent_tests";

# Temporary files used for saving failed test results in
my $FAILED_TESTS_FILE        = "$TMP_DIR/test.run";
my $FAILED_TESTS_FILE_SINGLE = "$FAILED_TESTS_FILE.single";

# Isolation constants
my $EXPECT_PASS = 0;
my $EXPECT_FAIL = 1;

my @bids = _get_bug_ids($BID);
foreach my $bid (@bids) {
    printf ("%4d: $project->{prog_name}\n", $bid);

    my %data;
    $data{$PROJECT} = $PID;
    $data{$ID} = $bid;

    # V2 must not have any failing tests
    my $list = _get_failing_tests($project, "$TMP_DIR/v2", "${bid}f");
    if (($data{$FAIL_V2} = (scalar(@{$list->{"classes"}}) + scalar(@{$list->{"methods"}}))) != 0) {
        print("Non expected failing test classes/methods on ${PID}-${bid}\n");
        _add_row(\%data);
        next;
    }

    # V1 must not have failing test classes but at least one failing test method
    $list = _get_failing_tests($project, "$TMP_DIR/v1", "${bid}b");
    my $fail_c = scalar(@{$list->{"classes"}}); $data{$FAIL_C_V1} = $fail_c;
    my $fail_m = scalar(@{$list->{"methods"}}); $data{$FAIL_M_V1} = $fail_m;
    if ($fail_c !=0 or $fail_m == 0) {
        print("Expected at least one failing test method on ${PID}-${bid}b\n");
        _add_row(\%data);
        next;
    }

    # Isolation part of workflow
    $list = $list->{methods}; # we only care about the methods from here on.
    my @fail_in_order = @$list; # list to compare isolated tests with

    # Make sure there are no duplicates.
    my %seen;
    for (@$list) {
        die "Duplicate test case failure: $_. Build is probably broken" unless ++$seen{$_} < 2;
    }

    print "List of test methods: \n" . join ("\n",  @$list) . "\n";
    # Run triggering test(s) in isolation on v2 -> tests should pass. Any test not
    # passing is excluded from further processing.
    $list = _run_tests_isolation("$TMP_DIR/v2", $list, $EXPECT_PASS);
    $data{$PASS_ISO_V2} = scalar(@$list);
    print "List of test methods: (passed in isolation on v2)\n" . join ("\n", @$list) . "\n";

    # Run triggering test(s) in isolation on v1 -> tests should fail. Any test not
    # failing is excluded from further processing.
    $list = _run_tests_isolation("$TMP_DIR/v1", $list, $EXPECT_FAIL);
    $data{$FAIL_ISO_V1} = scalar(@$list);
    print "List of test methods: (failed in isolation on v1)\n" . join ("\n", @$list) . "\n";

     # Save non-dependent triggering tests to $OUT_DIR/$bid
    if (scalar(@{$list}) > 0) {
        system("cp $FAILED_TESTS_FILE $OUT_DIR/$bid");
    } else {
        print("No triggering test case has been found. This could either mean that no test" .
              " has been executed or that all test cases pass (e.g., a javadoc change could" .
              " be considered bugfix however it might not be captured by any unit test case)\n");
    }

    # Save dependent tests to $DEP_TEST_FILE
    
    # Get contents of current dependent tests file
    my @old_dep_tests;

    if (-e $DEP_TEST_FILE){
        open my $contents, '<', $DEP_TEST_FILE or die "Cannot open dependent tests file: $!\n";
        my @old_dep_tests = <$contents>;
        close $contents;    
    }

    my @dependent_tests = grep { !($_ ~~  @{$list}) } @fail_in_order;
    for my $dependent_test (@dependent_tests) {
        # Add the test unless it is already in the list.
        unless ($dependent_test ~~ @old_dep_tests) {
            print " ## Warning: Dependent test ($dependent_test) is being added to list.\n";
            system("echo '--- $dependent_test' >> $DEP_TEST_FILE");
            push @old_dep_tests, $dependent_test;
        }
    }

    # Add data
    _add_row(\%data);
}

$dbh_trigger->disconnect();
$dbh_revs->disconnect();
system("rm -rf $TMP_DIR");

#
# Get bug ids from TAB_REV_PAIRS
#
sub _get_bug_ids {
    my $target_bid = shift;

    my $min_id;
    my $max_id;
    if (defined($target_bid) && $target_bid =~ /(\d+)(:(\d+))?/) {
        $min_id = $max_id = $1;
        $max_id = $3 if defined $3;
    }

    my $sth_exists = $dbh_trigger->prepare("SELECT * FROM $TAB_TRIGGER WHERE $PROJECT=? AND $ID=?") or die $dbh_trigger->errstr;

    # Select all version ids from previous step in workflow
    my $sth = $dbh_revs->prepare("SELECT $ID FROM $TAB_REV_PAIRS WHERE $PROJECT=? "
                . "AND $COMP_T2V1=1") or die $dbh_revs->errstr;
    $sth->execute($PID) or die "Cannot query database: $dbh_revs->errstr";
    my @bids = ();
    foreach (@{$sth->fetchall_arrayref}) {
        my $bid = $_->[0];
        # Skip if project & ID already exist in DB file
        $sth_exists->execute($PID, $bid);
        next if ($sth_exists->rows !=0);

        # Filter ids if necessary
        next if (defined $min_id && ($bid<$min_id || $bid>$max_id));

        # Add id to result array
        push(@bids, $bid);
    }
    $sth->finish();

    return @bids;
}

#
# Get a list of all failing tests
#
sub _get_failing_tests {
    my ($project, $root, $vid) = @_;

    # Clean output file
    system(">$FAILED_TESTS_FILE");
    $project->{prog_root} = $root;

    $project->checkout_vid($vid, $root, 1) or die;

    # Compile src and test
    $project->compile() or die;
    $project->compile_tests() or die;

    # Run tests and get number of failing tests
    $project->run_tests($FAILED_TESTS_FILE) or die;
    # Return failing tests
    return Utils::get_failing_tests($FAILED_TESTS_FILE);
}

#
# Run tests in isolation and check for pass/fail
#
sub _run_tests_isolation {
    my ($root, $list, $expect_fail) = @_;

    # Clean output file
    system(">$FAILED_TESTS_FILE");
    $project->{prog_root} = $root;

    my @succeeded_tests = ();

    foreach my $test (@$list) {
        # Clean single test output
        system(">$FAILED_TESTS_FILE_SINGLE");
        $project->run_tests($FAILED_TESTS_FILE_SINGLE, $test) or die;
        my $fail = Utils::get_failing_tests($FAILED_TESTS_FILE_SINGLE);
        if (scalar(@{$fail->{methods}}) == $expect_fail) {
            push @succeeded_tests, $test;
            system("cat $FAILED_TESTS_FILE_SINGLE >> $FAILED_TESTS_FILE"); # save results of single test to overall file.
        }
    }

    # Return reference to the list of methods passed/failed.
    \@succeeded_tests;
}

#
# Add a row to the database table
#
sub _add_row {
    my $data = shift;

    my @tmp;
    foreach (@COLS) {
        push (@tmp, $dbh_trigger->quote((defined $data->{$_} ? $data->{$_} : "-")));
    }

    my $row = join(",", @tmp);
    $dbh_trigger->do("INSERT INTO $TAB_TRIGGER VALUES ($row)");
}

=pod

=head1 SEE ALSO

Previous step in workflow is F<analyze-project.pl>.

Next step in workflow is running F<get-metadata.pl>.

=cut
