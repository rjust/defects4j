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

promote-to-db.pl -- Promote reproducible and minimized bugs and their metadata
to the main Defects4J database. In detail, this script copies over the following
metadata:
  - framework/core/Project/<PROJECT_ID>.pm
  - framework/projects/<PROJECT_ID>/build_files
  - framework/projects/<PROJECT_ID>/failing_tests
  - framework/projects/<PROJECT_ID>/lib
  - framework/projects/<PROJECT_ID>/loaded_classes
  - framework/projects/<PROJECT_ID>/modified_classes
  - framework/projects/<PROJECT_ID>/patches
  - framework/projects/<PROJECT_ID>/relevant_tests
  - framework/projects/<PROJECT_ID>/trigger_tests
  - framework/projects/<PROJECT_ID>/build.xml.patch
  - framework/projects/<PROJECT_ID>/<PROJECT_ID>.build.xml
  - framework/projects/<PROJECT_ID>/$BUGS_CSV_ACTIVE
  - framework/projects/<PROJECT_ID>/$BUGS_CSV_DEPRECATED	
  - framework/projects/<PROJECT_ID>/$LAYOUT_FILE
  - project_repos/<PROJECT_NAME>.git
and updates the project_repos/README file with information of when the project
repository was cloned.

=head1 SYNOPSIS

promote-to-db.pl -p project_id -w work_dir -r repository_dir [-b bug_id] [-o output_dir]

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the project for which the revision pairs are to be promoted.

=item B<-b C<bug_id>>

Only analyze this bug id. The bug_id has to follow the format B<(\d+)(:(\d+))?>.
Per default all bug ids, listed in the $BUGS_CSV_ACTIVE, are considered.

=item B<-w C<work_dir>>

The working directory used for the bug-mining process.

=item B<-r C<repository_dir>>

The path to the repository of this project.

=item B<-o C<output_dir>>

The output directory as the Defects4J directory. Defaults to F<$PROJECTS_DIR>.

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

my %cmd_opts;
getopts('p:w:r:b:o:d:', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{p} and defined $cmd_opts{w} and defined $cmd_opts{r};

my $PID = $cmd_opts{p};
my $WORK_DIR = abs_path($cmd_opts{w});
my $REPOSITORY_DIR = abs_path($cmd_opts{r});
my $BID = $cmd_opts{b};
my $OUTPUT_DIR = $cmd_opts{o} // "$SCRIPT_DIR/projects";

# Check format of target version id
if (defined $BID) {
    $BID =~ /^(\d+)(:(\d+))?$/ or die "Wrong bug id format ((\\d+)(:(\\d+))?): $BID!";
}

# Add script and core directory to @INC
unshift(@INC, "$WORK_DIR/framework/core");

# Override global constants
$PROJECTS_DIR = "$WORK_DIR/framework/projects";

system("mkdir -p $OUTPUT_DIR/$PID");

my $project = Project::create_project($PID);
my $dbh_trigger = DB::get_db_handle($TAB_TRIGGER, $WORK_DIR);

my @rev_specific_files = ("failing_tests/<rev>", "build_files/<rev>");
my @id_specific_files = ("loaded_classes/<id>.src", "loaded_classes/<id>.test",
                            "modified_classes/<id>.src", "modified_classes/<id>.test",
                            "patches/<id>.src.patch", "patches/<id>.test.patch",
                            "trigger_tests/<id>", "relevant_tests/<id>");
my @generic_files_and_directories_to_replace = ("build.xml.patch", "${PID}.build.xml", "lib", $BUGS_CSV_DEPRECATED);
my @generic_files_to_append = ("dependent_tests", $LAYOUT_FILE);

my @ids = _get_bug_ids($BID);
foreach my $id (@ids) {
    printf ("%4d: $project->{prog_name}\n", $id);

    my $v1 = $project->lookup("${id}b");
    my $v2 = $project->lookup("${id}f");

    my $issue_id  = $project->bug_report_id("${id}");
    my $issue_url = $project->bug_report_url("${id}");

    # find number
    my $max_number = 0;
    my $output_commit_db = "$OUTPUT_DIR/$PID/$BUGS_CSV_ACTIVE";
    if (-e $output_commit_db) {
        open FH, $output_commit_db or die "could not open output active-bugs csv";
        my $exists_line = 0;
        my $header = <FH>;
        while (my $line = <FH>) {
            chomp $line;
            $line =~ /^(\d+),(.*),(.*),(.*),(.*)$/ or die "could not parse line";
            $max_number = max($max_number, $1);
            if ("$2,$3,$4,$5" eq "$v1,$v2,$issue_id,$issue_url") {
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

    open FH, ">>$output_commit_db" or die "could not open output active-bugs csv for writing";

    # If this is the first bug to be promoted, print the header to the active-bugs csv file.
    if ($max_number == 1) {
        print FH $BUGS_CSV_BUGID.",".$BUGS_CSV_COMMIT_BUGGY.",".$BUGS_CSV_COMMIT_FIXED.",".$BUGS_CSV_ISSUE_ID.",".$BUGS_CSV_ISSUE_URL."\n";
    }

    print FH "$max_number,$v1,$v2,$issue_id,$issue_url\n";
    close FH;
    for my $rev ($v1, $v2) {
        for my $fn (@rev_specific_files) {
            my $fn_rev = $fn;
            $fn_rev =~ s/<rev>/$rev/;
            my $src = "$PROJECTS_DIR/$PID/$fn_rev";
            my $dst = "$OUTPUT_DIR/$PID/$fn_rev";
            _copy($src, $dst);
        }
    }
    for my $fn (@id_specific_files) {
        my $fn_src = $fn;
        $fn_src =~ s/<id>/$id/;
        my $fn_dst = $fn;
        $fn_dst =~ s/<id>/$max_number/;
        my $src = "$PROJECTS_DIR/$PID/$fn_src";
        my $dst = "$OUTPUT_DIR/$PID/$fn_dst";
        _copy($src, $dst);
    }
}

for my $fn (@generic_files_and_directories_to_replace) {
    my $src = "$PROJECTS_DIR/$PID/$fn";
    my $dst = "$OUTPUT_DIR/$PID/$fn";
    _copy($src, $dst);
}

for my $fn (@generic_files_to_append) {
    my $src = "$PROJECTS_DIR/$PID/$fn";
    my $dst = "$OUTPUT_DIR/$PID/$fn";
    _append($src, $dst);
}

# Copy project submodule
my $src = "$WORK_DIR/framework/core/Project/${PID}.pm";
my $dst = "$CORE_DIR/Project/${PID}.pm";
_copy($src, $dst);

# Copy repository directory
my $dir_name = $REPOSITORY_DIR;
$dir_name =~ m[^.*/(.*)$];
system ("rm -rf $REPO_DIR/$1") == 0 or die "Could not remove $REPO_DIR/$1: $!";
_copy($REPOSITORY_DIR, $REPO_DIR);

# Update README file
my $bug_miniming_repos_readme_file = "$WORK_DIR/project_repos/README";
my $d4j_repos_readme_file = "$REPO_DIR/README";
if (-e $bug_miniming_repos_readme_file) {
    if (-e $d4j_repos_readme_file) {
        system("cat $bug_miniming_repos_readme_file | while read -r row; do \
                    if ! grep -Eq \"\$row\" $d4j_repos_readme_file; then \
                        echo \"\$row\" >> $d4j_repos_readme_file; \
                    fi; \
                done") == 0 or die;
    } else {
        system("cat $bug_miniming_repos_readme_file > $d4j_repos_readme_file") == 0 or die;
    }
}

#
# Get bug ids from TAB_TRIGGER
#
sub _get_bug_ids {
    my $target_vid = shift;

    my $min_id;
    my $max_id;
    if (defined($target_vid) && $target_vid =~ /(\d+)(:(\d+))?/) {
        $min_id = $max_id = $1;
        $max_id = $3 if defined $3;
    }

    # Select all version ids from previous step in workflow
    my $sth = $dbh_trigger->prepare("SELECT $ID FROM $TAB_TRIGGER WHERE $PROJECT=? "
                . "AND $FAIL_ISO_V1>0") or die $dbh_trigger->errstr;
    $sth->execute($PID) or die "Cannot query database: $dbh_trigger->errstr";
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

sub _copy {
    my ($src, $dst) = @_;
    print "\t... copying $src -> $dst\n";
    $dst =~ m[^(.*)/.*$];
    system ("mkdir -p $1") == 0 or die "could not mkdir dest $1: $!";
    if (-e $src) {
        system("cp -R $src $dst") == 0 or die "could not copy $src: $!";
        print "\t... OK\n";
    }
}

sub _append {
    my ($src, $dst) = @_;
    print "\t... appending $src -> $dst\n";
    $dst =~ m[^(.*)/.*$];

    system ("mkdir -p $1") == 0 or die "could not mkdir dest $1: $!";
    if (-e $dst and -e $src) {
        open(SRC_FILE, '<', $src) or die "Cannot open src file ($src): $!";
        my @src_lines = <SRC_FILE>;
        close SRC_FILE;
        open(DST_FILE, '<', $dst) or die "Cannot open dst file ($dst): $!";
        my @dst_lines = <DST_FILE>;
        close DST_FILE;

        # Identify new lines to add to the file (do not re-append existing entries)
        my @new_lines = ();
        my %seen = ();
        foreach my $item (@dst_lines) {
            $seen{$item}++;
        }

        foreach my $item (@src_lines) {
            push(@new_lines, $item) unless $seen{$item}++;
        }

        open(my $DST_FILE, '>>', $dst) or die "Cannot open dst file ($dst)' $!"; 
        foreach my $line (@new_lines) {
            print $DST_FILE $line; 
        }
        close $DST_FILE;

        print "\t... OK\n";
    } elsif (-e $src) {
        system("cat $src >> $dst") == 0 or die "could not append $src: $!";
        print "\t... OK\n";

    }
}
