#! /usr/bin/env perl
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

promote-to-db.pl -- promote reproducible and minimized bugs with all meta data
                    to the main Defects4J database.

=head1 SYNOPSIS

promote-to-db.pl -p project_id -w work_dir [-b bug_id] [-o output_dir] [-d output_db_dir]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the project for which the revision pairs are to be promoted.

=item B<-b C<bug_id>>

Only promote this bug id or an interval of bug ids (optional).
The bug_id has to have the format B<(\d+)(:(\d+))?> -- if an interval is provided,
the interval boundaries are included in the analysis.
Per default all bug ids are considered.

=item B<-w C<work_dir>>

Use C<work_dir> as the working directory.

=item B<-o C<output_dir>>

Use C<output_dir> as the Defects4J directory. Defaults to F<$PROJECTS_DIR>.

=item B<-d C<output_db_dir>>

Use C<output_db_dir> as the C<result_db> directory. Defaults to F<$DB_DIR>.

=back

=cut
use strict;
use warnings;

use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use List::Util qw(all min max);
use Pod::Usage;

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;
use Project;
use DB;
use Utils;

############################## ARGUMENT PARSING
# Issue usage message and quit
sub _usage {
    die "usage: " . basename($0) . " -p project_id " .
        "-w WORK_DIR";
        "[-b bug_range] " .
        "[-o output_dir] " .
        "[-d output_db_dir] ";
}

my %cmd_opts;
getopts('p:w:b:o:d:', \%cmd_opts) or _usage();

my ($PID, $WORK_DIR, $BID, $output_dir, $output_db_dir) =
    ($cmd_opts{p},
     $cmd_opts{w},
     $cmd_opts{b},
     $cmd_opts{o} // "$SCRIPT_DIR/projects",
     $cmd_opts{d} // $DB_DIR);

# ok for BID to be undef
_usage() unless all {defined} ($PID, $WORK_DIR, $output_dir, $output_db_dir);

# Check format of target version id
if (defined $BID) {
    $BID =~ /^(\d+)(:(\d+))?$/ or die "Wrong bug id format ((\\d+)(:(\\d+))?): $BID!";
}

$WORK_DIR = abs_path("$WORK_DIR");

system("mkdir -p $output_dir/$PID");
system("mkdir -p $output_db_dir");

############################### COPY/CREATE RELEVANT FILES
system("cp $WORK_DIR/framework/core/Project/$PID.pm ../core/Project");
system("cp $WORK_DIR/framework/projects/$PID/$PID.build.xml ../projects/$PID");
system("cp $WORK_DIR/framework/projects/$PID/dir-layout.csv ../projects/$PID");
system("touch ../projects/$PID/commit-db");
############################### VARIABLE SETUP
my $project = Project::create_project($PID); #, $WORK_DIR, "$WORK_DIR/$PID/commit-db", "$WORK_DIR/$PID/$PID.build.xml");
my $dbh_trigger_in = DB::get_db_handle($TAB_TRIGGER, $WORK_DIR);
my $dbh_trigger_out = DB::get_db_handle($TAB_TRIGGER, $output_db_dir);
my $dbh_revs_in = DB::get_db_handle($TAB_REV_PAIRS, $WORK_DIR);
my $dbh_revs_out = DB::get_db_handle($TAB_REV_PAIRS, $output_db_dir);

my @rev_specific_files = ("failing_tests/<rev>",);
my @id_specific_files = ("loaded_classes/<id>.src", "loaded_classes/<id>.test",
                            "modified_classes/<id>.src", "modified_classes/<id>.test",
                            "patches/<id>.src.patch", "patches/<id>.test.patch",
                            "trigger_tests/<id>");
my @generic_files = ("dependent_tests");

############################### MAIN LOOP
# figure out which IDs to run script for
my @ids = _get_version_ids($BID);
foreach my $id (@ids) {
    printf ("%4d: $project->{prog_name}\n", $id);
    my $v1 = $project->lookup("${id}b");
    my $v2 = $project->lookup("${id}f");
    # find number
    my $max_number = 0;
    my $output_commit_db = "$output_dir/$PID/commit-db";
    if (-e $output_commit_db) {
        open FH, $output_commit_db or die "could not open output commit-db";
        my $exists_line = 0;
        while (my $line = <FH>) {
            chomp $line;
            $line =~ /^(\d+),(.*),(.*)$/ or die "could not parse line";
            $max_number = max($max_number, $1);
            if ("$2,$3" eq "$v1,$v2") {
                $exists_line = $1;
                last;
            }
        }
        close FH;
        if ($exists_line) {
            print "\t... not adding, exists as $exists_line\n";
            next;
        }
    }
    ++$max_number;
    print "\t... adding as new commit-id $max_number\n";


    open FH, ">>$output_commit_db" or die "could not open output commit-db for writing";
    print FH "$max_number,$v1,$v2\n";
    close FH;
    for my $rev ($v1, $v2) {
        for my $fn (@rev_specific_files) {
            $fn =~ s/<rev>/$rev/;
            my $src = "$WORK_DIR/$PID/$fn";
            my $dst = "$output_dir/$PID/$fn";
            _cp($src, $dst);
        }
    }
    for my $fn (@id_specific_files) {
        my $fn_src = $fn; $fn_src =~ s/<id>/$id/;
        my $fn_dst = $fn; $fn_dst =~ s/<id>/$max_number/;
        my $src = "$WORK_DIR/$PID/$fn_src";
        my $dst = "$output_dir/$PID/$fn_dst";
        _cp($src, $dst);
    }

    # write to dbs
    _db_cp($dbh_trigger_in, $dbh_trigger_out, $TAB_TRIGGER, $id, $max_number);
    _db_cp($dbh_revs_in, $dbh_revs_out, $TAB_REV_PAIRS, $id, $max_number);
}

for my $fn (@generic_files) {
    my $src = "$WORK_DIR/$PID/$fn";
    my $dst = "$output_dir/$PID/$fn";
    my $tmp = "$output_dir/$PID/${fn}_tmp";
    if (-e $src) {
        `cat $src >> $dst && cp $dst $tmp && sort -u $tmp > $dst`;
        die unless ($? == 0);
        `rm -rf $tmp`;
    }
}


############################### SUBROUTINES
# Get version ids from TAB_TRIGGER
sub _get_version_ids {
    my $target_vid = shift;

    my $min_id;
    my $max_id;
    if (defined($target_vid) && $target_vid =~ /(\d+)(:(\d+))?/) {
        $min_id = $max_id = $1;
        $max_id = $3 if defined $3;
    }

    # Select all version ids from previous step in workflow
    my $sth = $dbh_trigger_in->prepare("SELECT $ID FROM $TAB_TRIGGER WHERE $PROJECT=? "
                . "AND $FAIL_ISO_V1>0") or die $dbh_trigger_in->errstr;
    $sth->execute($PID) or die "Cannot query database: $dbh_trigger_in->errstr";
    my @ids = ();
    foreach (@{$sth->fetchall_arrayref}) {
        my $vid = $_->[0];

        # Filter ids if necessary
        next if (defined $min_id && ($vid<$min_id || $vid>$max_id));

        # Add id to result array
        push(@ids, $vid);
    }
    $sth->finish();

    return @ids;
}

sub _cp {
    my ($src, $dst) = @_;
    print "\t... copying $src -> $dst\n";
    $dst =~ m[^(.*)/.*$];
    system ("mkdir -p $1") == 0 or die "could not mkdir dest $1: $!";
    if (-e $src) {
        system("cp $src $dst") == 0 or die "could not copy $src: $!";
    }
}

sub _db_cp {
    my ($db_in, $db_out, $tab, $id, $new_id) = @_;
    my $stmnt = $db_in->prepare("SELECT * FROM $tab WHERE $PROJECT=? AND $ID=?")
        or die $db_in->errstr;
    $stmnt->execute($PID, $id);
    my @vals = $stmnt->fetchrow_array;
    $stmnt->finish();
    $vals[0] = "'" . $vals[0] . "'";
    $vals[1] = $new_id;
    my $row = join(',', @vals);
    $db_out->do("INSERT INTO $tab VALUES ($row)") or die $db_out->errstr;
}
