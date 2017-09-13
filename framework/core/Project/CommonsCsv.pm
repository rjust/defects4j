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

Project/CommonsCsv.pm -- Concrete project instance for CommonsCsv.

=head1 DESCRIPTION

This module provides all project-specific configurations and methods for the
CommonsCsv project.

=cut
package Project::CommonsCsv;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "CommonsCsv";

sub new {
    my $class = shift;
    my $work_dir = shift // "$SCRIPT_DIR/projects";
    my $name = "commonscsv";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$work_dir/$PID/commit-db");

    return $class->SUPER::new($PID, $name, $vcs, $work_dir);
}

#
# Determine the project layout for the checked-out version.
#
sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $revision_id) = @_;
    my $work_dir = $self->{prog_root};

	if (-e "$work_dir/src"){
		return {src=>"src/main", test=>"src/test"};
	}
}


1;

=pod

=head1 SEE ALSO

F<Project.pm>

=cut
