#-------------------------------------------------------------------------------
# Copyright (c) 2014-2015 René Just, Darioush Jalali, and Defects4J contributors.
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

Coverage.pm -- Provides helper functions for coverage analysis. 

=head1 DESCRIPTION

This module provides helper functions for coverage analysis using Cobertura.

=cut
package Coverage;

use warnings;
use strict;

use Constants;
use Utils;
use DB;

# Cache column names for table coverage
my @COLS = DB::get_tab_columns($TAB_COVERAGE) or die "Cannot obtain table columns!";

# Default paths
my $FAIL_FILE = "coverage_fails";
my $SER_FILE = "cobertura.ser";
my $XML_FILE = "coverage/coverage.xml";
my $XML_DIR  = "coverage";

# Corbetura scripts
my $CORBETURA_MERGE  = "$SCRIPT_DIR/projects/lib/cobertura-merge.sh";
my $CORBETURA_REPORT = "$SCRIPT_DIR/projects/lib/cobertura-report.sh";

=pod

=head2 Helper functions

=over 4

=item B<coverage> C<coverage(project_ref, modified_classes_file, src_dir, [single_test, [merge_with]])>

Runs coverage for a provided project. C<modified_classes_file> specifies
a file listing all the classes which should be instrumented.
C<src_dir> provides the root of the source code. This is necessary for cobertura
to generate reports.

If C<single_test> is specified, only that test is run. This is meant to be used
in conjunction with C<merge_with> (= path to a .ser file obtained by running 
coverage) to enable incremental analysis.

=back

=cut
sub coverage {
	@_ >= 3 or die $ARG_ERROR;
	my ($project, $modified_classes_file, $src_dir, $single_test, $merge_with) = @_;

	my $pid = $project->{pid};

	$project->coverage_instrument($modified_classes_file) == 0 or return undef;

	my $failure_file = "$project->{prog_root}/$FAIL_FILE"; 
	system(">$failure_file");
	$project->coverage($failure_file) == 0 or return undef;
    Utils::has_failing_tests($failure_file) and return undef;

	my $root = $project->{prog_root};
	my $datafile = "$root/datafile";
	my $xmlfile  = "$root/$XML_FILE";
	my $xmldir   = "$root/$XML_DIR";
	my $my_ser   = "$root/$SER_FILE";

	my $result_xml;
	if (defined $merge_with) {
		print "Merging & creating new report via shell script..\n";

		# Remove stale data files
		system("rm -f $datafile") if -e $datafile;
		system("rm -f $xmlfile")  if -e $xmlfile ;
	
		system("sh $CORBETURA_MERGE --datafile $datafile $merge_with $my_ser >/dev/null 2>&1") == 0 or die "could not merge results";
		system("sh $CORBETURA_REPORT --format xml --datafile $datafile --destination $xmldir >/dev/null 2>&1") == 0 or die "could not create report";

	} else {
		# Generate XML directly if merge is not needed.
		$project->coverage_report($src_dir) == 0 or die "could not create report";
	}

	return  _get_info_from_xml($xmlfile);
}

=pod

=over 4

=item B<coverage_ext> C<coverage_ext(project, classes_to_instrument_file, src_dir, test_dir, include_pattern, log_file)>

Determines code coverage for a generated test suite. C<classes_to_instrument_file> specifies
a file listing all the classes which should be instrumented.
C<src_dir> provides the root of the source code. This is necessary for cobertura
to generate reports.

=back

=cut
sub coverage_ext {
	@_ == 6 or die $ARG_ERROR;
	my ($project, $classes_file, $src_dir, $test_dir, $include, $log_file) = @_;

    # Instrument all classes provided
	$project->coverage_instrument($classes_file) == 0 or return undef;

    # Execute test suite
	$project->run_ext_tests($test_dir, $include, $log_file) == 0 or die "Could not run test suite";

    # Generate coverage report
	$project->coverage_report($src_dir) == 0 or die "Could not create report";

    # Parse xml output and return coverage ratios
	my $xmlfile  = "$project->{prog_root}/$XML_FILE";
	return _get_info_from_xml($xmlfile);
}


=pod

=over 4

=item B<insert_row> C<insert_row(hashref, [out_dir])>

Insert a row into the database table $TAB_COVERAGE.
C<hashref> contains a hash pointing to those data.
C<out_dir> is the optional alternative database directory to use.

=back

=cut
sub insert_row {
    my ($data, $out_dir) = @_;
    
	# Get proper output db handle: check whether a different output directory is provided
    my $dbh;
    if (defined $out_dir) {
        $dbh = DB::get_db_handle($TAB_COVERAGE, $out_dir);
    } else {
        $dbh = DB::get_db_handle($TAB_COVERAGE);
    }
 
    my @tmp;
    foreach (@COLS) {
        push (@tmp, $dbh->quote((defined $data->{$_} ? $data->{$_} : "-")));
    }

    my $row = join(",", @tmp);
    $dbh->do("INSERT INTO $TAB_COVERAGE VALUES ($row)");
}


=pod

=over 4

=item B<copy_coverage_logs> C<copy_coverage_logs(project, vid, suite, test_id, log_dir)>

Copies the coverage log files to a permanent directory C<log_dir>.
C<project> is the project refid, C<vid> is the version ID, C<suite> specifies
the suite tag (e.g., manual, evosuite), and C<test_id> provides the ID of the 
trigger test.

=back

=cut
sub copy_coverage_logs {
    my ($project, $vid, $suite, $test_id, $log_dir) = @_;

	# Copy coverage log files to log directory
    system("cp $project->{prog_root}/$SER_FILE $log_dir/$suite/$vid.$test_id.ser") == 0
        or die "Cannot copy .ser file";
	system("cp $project->{prog_root}/$XML_FILE $log_dir/$suite/$vid.$test_id.xml") == 0
		or die "Cannot copy .xml file";
}

# 
# Parse coverage log file and return reference to a hash that holds all results
#
sub _get_info_from_xml {
    my ($xml, ) = @_;
    my ($lt, $lc, $bt, $bc);

    -e $xml or die "no xml file";

    # Parse XML file
    open FH, $xml;
    while (<FH>) {
        if (/lines-covered="(\d+)" lines-valid="(\d+)" branches-covered="(\d+)" branches-valid="(\d+)"/) {
            ($lc, $lt, $bc, $bt) = ($1, $2, $3, $4);
        }
    }
    close FH;

    die "values not set" unless defined $lt;
    
    # Set all values and return hash reference
    return {
        $LINES_TOTAL => $lt,
        $LINES_COVERED => $lc,
        $BRANCHES_TOTAL => $bt,
        $BRANCHES_COVERED => $bc,
    };
}

=pod

=head1 SEE ALSO

All constants are defined in F<Constants.pm>. This module uses the database 
back-end F<DB.pm>.

=cut
