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

get-metadata.pl -- Generates the bug meta data (modified classes, loaded
classes, relevant tests) for each reproducible bug.

=head1 SYNOPSIS

get-metadata.pl -p project_id -w work_dir [-b bug_id]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the project for which the meta data should be generated.

=item B<-w F<work_dir>>

The working directory used for the bug-mining process.

=item B<-b C<bug_id>>

Only analyze this bug id. The bug_id has to follow the format B<(\d+)(:(\d+))?>.
Per default all bug ids, listed in the active-bugs csv, are considered.

=back

=head1 DESCRIPTION

This script runs each triggerng test in isolation, monitors the class loader,
and exports the class names of loaded and modified classes. It also, determines
the set of relevant tests (i.e., tests that touch at least one of the modified
classes).

This script runs the following workflow for the provided C<project_id>. For each
bug that has at least one (reviewed) triggering test(s) in L<TAB_TRIGGER|DB>:

=over 4

=item 1) Checkout fixed version.

=item 2) Compile src and test.

=item 3) Run triggering test(s), verify that they pass, monitor class loader,
         and export the list of class names (loaded classes).

=item 4) Determine modified source files from source patch and export the list
         of class names (modified classes).

=item 5) Run each test class (monitor the class loader) and determine whether it
         loads at least one modified class. Export the set of all test classes
         that do load at least one modified class (relevant tests).

=back

This script writes the loaded classes, modified classes, and relevant tests to:

=over 4

=item * F<C<PROJECTS_DIR>/"project_id"/loaded_classes>

=item * F<C<PROJECTS_DIR/"project_id"/modified_classes>

=item * F<C<PROJECTS_DIR/"project_id"/relevant_tests>

=back

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

# Add script and core directory to @INC
unshift(@INC, "$WORK_DIR/framework/core");

# Override global constants
$REPO_DIR = "$WORK_DIR/project_repos";
$PROJECTS_DIR = "$WORK_DIR/framework/projects";

my $PROJECT_DIR = "$PROJECTS_DIR/$PID";
# Directories for loaded and modified classes
my $LOADED = "$PROJECT_DIR/loaded_classes";
my $MODIFIED = "$PROJECT_DIR/modified_classes";

# Directories containing triggering tests and relevant tests
my $TRIGGER = "$PROJECT_DIR/trigger_tests";
my $RELEVANT= "$PROJECT_DIR/relevant_tests";

# DB_CSVs directory
my $db_dir = $WORK_DIR;

# Temporary directory
my $TMP_DIR = Utils::get_tmp_dir();
system("mkdir -p $TMP_DIR");

# Check if output directories exit
-d $LOADED or die "$LOADED does not exist: $!";
-d $MODIFIED or die "$MODIFIED does not exist: $!";
-d $RELEVANT or die "$RELEVANT does not exist: $!";

# Set up project
my $project = Project::create_project($PID);
$project->{prog_root} = $TMP_DIR;

my @bids = _get_bug_ids($BID);
foreach my $bid (@bids) {
    # Lookup revision ids
    my $v1  = $project->lookup("${bid}b");
    my $v2  = $project->lookup("${bid}f");

    my $file = "$TRIGGER/$bid";
    -e $file or die "Triggering test does not exist: $file!";

    my @list = @{Utils::get_failing_tests($file)->{methods}};
    # There has to be a triggering test
    scalar(@list) > 0 or die "No triggering test: $v2";

    printf ("%4d: $project->{prog_name}\n", $bid);

    # Checkout to version 2
    $project->checkout_vid("${bid}f", $TMP_DIR, 1) or die;

    # Compile sources and tests
    $project->compile() or die;
    $project->compile_tests() or die;

    my %src;
    my %test;
    foreach my $test (@list) {
        my $log_file = "$TMP_DIR/tests.fail";

        # Run triggering test and verify that it passes
        $project->run_tests($log_file, $test) or die;

        # Get number of failing tests -> has to be 0
        my $fail = Utils::get_failing_tests($log_file);
        (scalar(@{$fail->{classes}}) + scalar(@{$fail->{methods}})) == 0 or die "Unexpected failing test on fixed project version (see $log_file)!";

        # Run tests again and monitor class loader
        my $loaded = $project->monitor_test($test, "${bid}f");
        die unless defined $loaded;

        foreach (@{$loaded->{src}}) {
            $src{$_} = 1;
        }
        foreach (@{$loaded->{test}}) {
            $test{$_} = 1;
        }
    }

    # Write list of loaded classes
    open(OUT, ">$LOADED/$bid.src") or die "Cannot write loaded classes!";
    foreach (sort { "\L$a" cmp "\L$b" } keys %src) {
        print OUT "$_\n";
    }
    close(OUT);

    # Write list of loaded test classes
    open(OUT, ">$LOADED/$bid.test") or die "Cannot write loaded test classes!";
    foreach (sort { "\L$a" cmp "\L$b" } keys %test) {
        print OUT "$_\n";
    }
    close(OUT);

    # Export variables to make sure the get_modified_classes script picks up the right directories.
    $ENV{'PROJECTS_DIR'} = abs_path($PROJECTS_DIR);
    $ENV{'REPO_DIR'} = abs_path($REPO_DIR);
    # TODO: This should also be configurable in Constants.pm
    my $perl_lib = $ENV{'PERL5LIB'} // "";
    $ENV{'PERL5LIB'} = "$WORK_DIR/framework/core:$perl_lib";
    # Determine modified files
    #
    # Note:
    # This util script uses the possibly minimized source patch file instead of
    # the Vcs-diff between the pre-fix and post-fix revision.
    Utils::exec_cmd("$UTIL_DIR/get_modified_classes.pl -p $PID -b $bid > $MODIFIED/$bid.src",
            "Exporting the set of modified classes");

    # Determine and export all relevant test classes
    _export_relevant_tests($bid);
}
# Remove temporary directory
system("rm -rf $TMP_DIR");

#
# Determine all suitable version ids:
# - Source patch is reviewed
# - Triggering test exists
#    + Triggering test fails in isolation on rev1
#
sub _get_bug_ids {
    my $target_bid = shift;

    my $min_id;
    my $max_id;
    if (defined($target_bid) && $target_bid =~ /(\d+)(:(\d+))?/) {
        $min_id = $max_id = $1;
        $max_id = $3 if defined $3;
    }

    my @ids = ();

    if (-e "$db_dir/$TAB_TRIGGER") {
        # Connect to database
        my $dbh = DB::get_db_handle($TAB_TRIGGER, $db_dir);

        # Select all version ids with reviewed src patch and verified triggering test
        my $sth = $dbh->prepare("SELECT $ID FROM $TAB_TRIGGER " .
                                    "WHERE $FAIL_ISO_V1>0 AND $PROJECT=?")
                                or die $dbh->errstr;
        $sth->execute($PID) or die "Cannot query database: $dbh->errstr";

        foreach (@{$sth->fetchall_arrayref}) {
            my $bid = $_->[0];

            # Filter ids if necessary
            next if (defined $min_id && ($bid<$min_id || $bid>$max_id));

            # Add id to result array
            push(@ids, $bid);
        }
        $sth->finish();
        $dbh->disconnect();
    } elsif (defined $min_id && defined $max_id) {
        @ids = ($min_id .. $max_id);
    }

    scalar(@ids) > 0 or die "No bug ids are suitable to run ./get-metadata.pl on";
    return @ids;
}

#
# Determine all relevant tests
#
sub _export_relevant_tests {
    my $bid = shift;

    # Hash all modified classes
    my %mod_classes = ();
    open(IN, "<$MODIFIED/${bid}.src") or die "Cannot read modified classes";
    while(<IN>) {
        chomp;
        $mod_classes{$_} = 1;
    }
    close(IN);

    # Result: list of relevant tests
    my @relevant = ();

    # Iterate over all tests and determine whether or not a test is relevant
    my @all_tests = `cd $TMP_DIR && $SCRIPT_DIR/bin/defects4j export -ptests.all`;
    foreach my $test (@all_tests) {
        chomp($test);
        print(STDERR "Analyze test: $test\n");
        my $loaded = $project->monitor_test($test, "${bid}f");
        die("Failed test: $test\n") unless (defined $loaded);

        foreach my $class (@{$loaded->{src}}) {
            if (defined $mod_classes{$class}) {
                push(@relevant, $test);
                # A test is relevant if it loads at least one of the modified
                # classes!
                last;
            }
        }
    }
    open(OUT, ">$RELEVANT/$bid") or die "Cannot write relevant tests";
    for (@relevant) {
        print(OUT $_, "\n");
    }
    close(OUT);
}

=pod

=head1 SEE ALSO

This script should be executed after getting the list of trigger tests by
running the F<get-trigger.pl> script. After running this script, you can inspect
whether the patch of each revision is indeed minimal. Then you can use
F<promote-to-db.pl> script to merge desired revisions with the main database.

=cut
