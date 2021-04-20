#!/usr/bin/env perl
##
##-------------------------------------------------------------------------------
## Copyright (c) 2014-2018 René Just, Darioush Jalali, and Defects4J contributors.
##
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice shall be included in
## all copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
## THE SOFTWARE.
##-------------------------------------------------------------------------------
use warnings;
use strict;

use FindBin;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Mutation;
use Project;
use Utils;
use Log;

#
## Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('p:d:v:t:o:f:i:DAT:m:P:', \%cmd_opts) or pod2usage(1);

my $PID = $cmd_opts{p};
my $VID = $cmd_opts{v} if defined $cmd_opts{v};

# Set up project
my $project = Project::create_project($PID);

# Check format of target version id
if (defined $VID) {
    # Verify that the provided version id is valid
    Utils::check_vid($VID);
    $project->contains_version_id($VID) or die "Version id ($VID) does not exist in project: $PID";
}

# Output directory for results
system("mkdir -p $cmd_opts{o}");
my $OUT_DIR = abs_path($cmd_opts{o});

# Temporary directory for execution
my $TMP_DIR = Utils::get_tmp_dir($cmd_opts{t});
system("mkdir -p $TMP_DIR");

# Log directory and file
my $TAB_MUTATION = ($ENV{TAB_MUTATION} or "mutation");
my $LOG_DIR = "$OUT_DIR/${TAB_MUTATION}_log/$PID";
my $LOG_FILE = "$LOG_DIR/" . basename($0) . ".log";
system("mkdir -p $LOG_DIR");

# Open temporary log file
my $LOG = Log::create_log("$TMP_DIR/". basename($0) . ".log");
$LOG->log_time("Start mutation analysis");
`mkdir -p $LOG_DIR/"dev"`;

_run_mutation_dev($VID);

# Log current time
$LOG->log_time("End mutation analysis");
$LOG->close();

# Copy log file and clean up temporary directory
system("cat $LOG->{file_name} >> $LOG_FILE") == 0 or die "Cannot copy log file";
system("rm -rf $TMP_DIR");


# Run mutation analysis for tests on the version they were created for.
sub _run_mutation_dev {
    my ($vid) = @_;

    my $result = Utils::check_vid($vid);
    my $bid   = $result->{bid};
    my $type  = $result->{type};

    # Checkout program version
    my $root = "$TMP_DIR/${vid}";
    $project->{prog_root} = "$root";
    $project->checkout_vid($vid) or die "Checkout failed";

    my $mut_log = "$TMP_DIR/.mutation.log"; `>$mut_log`;
  
    my $mut_map = Mutation::mutation_analysis_pit_dev($project, $mut_log);
    Mutation::copy_pit_results($project, $vid, "dev", "dev", $mut_log, $LOG_DIR);
    }
