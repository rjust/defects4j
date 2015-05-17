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

Project/Lang.pm -- Concrete project instance for Commons-lang.

=head1 DESCRIPTION

This module provides all project-specific configurations and methods for the
Commons-lang project.

=cut
package Project::Lang;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "Lang";
my $RANDOM_TEST_FILE = "$SCRIPT_DIR/build-scripts/$PID/random_tests";

sub new {
    my $class = shift;
    my $work_dir = shift // "$SCRIPT_DIR/projects";
    my $name = "commons-lang";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$work_dir/$PID/commit-db",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs, $work_dir);
}

sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $revision_id) = @_;
    my $dir = $self->{prog_root};
    my $result = _layout1($dir) // _layout2($dir);
    die "Unknown layout for revision: ${revision_id}" unless defined $result;
    return $result;
}

# Remove randomly failing tests in addition to the broken ones
sub fix_tests {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $revision_id) = @_;

    # Call fix_tests in super class to fix all broken methods
    $self->SUPER::fix_tests($revision_id);

    # TODO: Exclusively use version ids rather than revision ids
    $revision_id = $self->lookup($revision_id) if $revision_id =~ /\d+[bf]/;

    # Remove randomly failing tests
    my $work_dir = $self->{prog_root};
    my $dir = $self->test_dir($revision_id);

    if (-e $RANDOM_TEST_FILE) {
        # Remove test methods that fail statistically
        $self->exclude_tests_in_file($RANDOM_TEST_FILE, $dir);
    }
}

sub _post_checkout {
    my ($vcs, $revision, $work_dir) = @_;
    my $name = $vcs->{prog_name};

    # Check whether ant build file exists
    unless (-e "$work_dir/build.xml") {
        my $generated_buildfile_dir = "$SCRIPT_DIR/build-scripts/$PID/build_files/$revision";
        unless (-e "$generated_buildfile_dir/build.xml") {
            print "Maven buildfile -> Ant buildfile for: $revision...";
            Utils::maven_to_ant("$SCRIPT_DIR/build-scripts/$PID/build.xml.patch",
                                $work_dir,
                                $generated_buildfile_dir);
        }
        system("cp $generated_buildfile_dir/* $work_dir") == 0 or die;
    }
}

sub initialize_revision {
    my ($self, $revision) = @_;
    $self->SUPER::initialize_revision($revision);
    _log_random_tests($self->{prog_root} . "/" . $self->test_dir($revision), $RANDOM_TEST_FILE);
}

# Search for randomly failing tests in all java files
sub _log_random_tests {
    my ($test_dir, $out_file) = @_;
    @_ == 2 or die $ARG_ERROR;
    # TODO: Move to Consts
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

# Existing build.xml and default.properties
sub _layout1 {
    my $dir = shift;
    my $src  = `grep "source.home" $dir/default.properties 2>/dev/null`;
    my $test = `grep "test.home" $dir/default.properties 2>/dev/null`;

    return undef if ($src eq "" || $test eq "");

    $src =~ s/\s*source.home\s*=\s*(\S+)\s*/$1/;
    $test=~ s/\s*test.home\s*=\s*(\S+)\s*/$1/;

    return {src=>$src, test=>$test};
}

# Generated build.xml (mvn ant:ant) with maven-build.properties
sub _layout2 {
    my $dir = shift;
    my $src  = `grep "maven.build.srcDir.0" $dir/maven-build.properties 2>/dev/null`;
    my $test = `grep "maven.build.testDir.0" $dir/maven-build.properties 2>/dev/null`;

    return undef if ($src eq "" || $test eq "");

    $src =~ s/\s*maven\.build\.srcDir\.0\s*=\s*(\S+)\s*/$1/;
    $test=~ s/\s*maven\.build\.testDir\.0\s*=\s*(\S+)\s*/$1/;

    return {src=>$src, test=>$test};
}

1;

=pod

=head1 SEE ALSO

F<Project.pm>

=cut

