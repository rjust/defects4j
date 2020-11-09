#-------------------------------------------------------------------------------
# Copyright (c) 2014-2019 René Just, Darioush Jalali, and Defects4J contributors.
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

Project::Lang.pm -- L<Project> submodule for Commons-lang.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
Commons-lang project.

=cut
package Project::Lang;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "Lang";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "commons-lang";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs);
}

#
# Determines the directory layout for sources and tests
#
sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $rev_id) = @_;
    my $dir = $self->{prog_root};
    my $result = _layout1($dir) // _layout2($dir);
    die "Unknown layout for revision: ${rev_id}" unless defined $result;
    return $result;
}

#
# Existing Ant build.xml and default.properties
#
sub _layout1 {
    @_ == 1 or die $ARG_ERROR;
    my ($dir) = @_;
    my $src  = `grep "source.home" $dir/default.properties 2>/dev/null`;
    my $test = `grep "test.home" $dir/default.properties 2>/dev/null`;

    return undef if ($src eq "" || $test eq "");

    $src =~ s/\s*source.home\s*=\s*(\S+)\s*/$1/;
    $test=~ s/\s*test.home\s*=\s*(\S+)\s*/$1/;

    return {src=>$src, test=>$test};
}

#
# Generated build.xml (from mvn ant:ant) with maven-build.properties
#
sub _layout2 {
    @_ == 1 or die $ARG_ERROR;
    my ($dir) = @_;
    my $src  = `grep "maven.build.srcDir.0" $dir/maven-build.properties 2>/dev/null`;
    my $test = `grep "maven.build.testDir.0" $dir/maven-build.properties 2>/dev/null`;

    return undef if ($src eq "" || $test eq "");

    $src =~ s/\s*maven\.build\.srcDir\.0\s*=\s*(\S+)\s*/$1/;
    $test=~ s/\s*maven\.build\.testDir\.0\s*=\s*(\S+)\s*/$1/;

    return {src=>$src, test=>$test};
}

#
# Copy the generated build.xml, if necessary.
#
sub _post_checkout {
    my ($self, $revision_id, $work_dir) = @_;

    # Check whether ant build file exists
    unless (-e "$work_dir/build.xml") {
        system("cp $PROJECTS_DIR/$PID/build_files/$revision_id/* $work_dir");
    }
}

#
# Determine and log random tests when initializing a revision.
#
sub initialize_revision {
    my ($self, $revision, $vid) = @_;
    $self->SUPER::initialize_revision($revision);
    # TODO: define the file name for random tests in Constants
    my $random_tests_file = "$PROJECTS_DIR/$self->{pid}/random_tests";
    _log_random_tests($self->{prog_root} . "/" . $self->test_dir($vid), $random_tests_file);
}

#
# Search for clearly labeled, randomly failing tests in all Java files
#
sub _log_random_tests {
    my ($test_dir, $out_file) = @_;
    @_ == 2 or die $ARG_ERROR;
    # TODO: Move to Constants
    my $PREFIX = "---";
    my @list = `cd $test_dir && find . -name *.java`;
    die if $?!=0 or !@list;

    foreach my $file (@list) {
        chomp $file;
        open(IN, "<$test_dir/$file") or die $!;
        my @reason = ();
        my $rnd=0;
        while (<IN>) {
            if (!$rnd) {
                next unless /(\*|\/\/).*randomly/;
                $rnd=1;
            }
            if ($rnd and /\s*public\s*void\s*([^\(]*)\s*\(/) {
                my $method=$1;
                my $class = $file;
                $class =~ s/\.\/(.*).java/$1/; $class =~ s/\//\./g;
                my $key = "${class}::$method";
                # Only print method if it is not already in the result file
                Utils::append_to_file_unless_matches($out_file,
                    join('', @reason) . "$PREFIX $key\n\n",
                    qr/$PREFIX $key/
                );
                @reason = ();
                $rnd=0; next;
            }
            push(@reason, $_);
        }
        close(IN);
    }
}

1;
