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
use File::Path 'rmtree';

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
    my ($self, $revision_id) = @_;
    my $work_dir = $self->{prog_root};

    # Only two sets of layouts in this case
    my $result;
    if (-e "$work_dir/src/main"){
      $result = {src=>"src/main/java", test=>"src/test/java"};
    }
    if (-e "$work_dir/src/java"){
      $result = {src=>"src/java", test=>"src/test"};
    }
    die "Unknown layout for revision: ${revision_id}" unless defined $result;
    return $result;
}

#
# Copy the generated build.xml, if necessary.
#
sub _post_checkout {
    my ($self, $revision_id, $work_dir) = @_;

    my $bid = Utils::get_bid($work_dir);

    # Fix compilation errors if necessary.
    # Run this as the first step to ensure that patches are applicable to
    # unmodified source files.
    my $compile_errors = "$PROJECTS_DIR/$self->{pid}/compile-errors/";
    opendir(DIR, $compile_errors) or die "Could not find compile-errors directory.";
    my @entries = readdir(DIR);
    closedir(DIR);
    foreach my $file (@entries) {
        if ($file =~ /-(\d+)-(\d+).diff/) {
            if ($bid >= $1 && $bid <= $2) {
                $self->apply_patch($work_dir, "$compile_errors/$file")
                        or confess("Couldn't apply patch ($file): $!");
            }
        }
    }

    # Convert the file encoding of problematic files
    my $result = determine_layout($self, $revision_id);
    Utils::convert_file_encoding($work_dir."/".$result->{src}."/org/apache/commons/lang3/text/translate/EntityArrays.java");
    Utils::convert_file_encoding($work_dir."/".$result->{src}."/org/apache/commons/lang/Entities.java");


    # Some of the Lang tests were created pre Java 1.5 and contain an 'enum' package.
    # The is now a reserved word in Java so we convert all references to 'oldenum'.
    if (-d "$work_dir/$result->{src}/org/apache/commons/lang/enum/") {
        Utils::exec_cmd("grep -lR '\\.enum;' $work_dir'/'$result->{src}'/org/apache/commons/lang/enum/' | xargs sed -i'.bak' 's/\\.enum;/\\.oldenum;/'", "Rename enum package in src") or die;
        Utils::exec_cmd("cd $work_dir/$result->{src}/org/apache/commons/lang && mv enum oldenum", "Move enum package in src") or die;
    }

    if (-d "$work_dir/$result->{test}/org/apache/commons/lang/enum/") {
        Utils::exec_cmd("grep -lR '\\.enum;' $work_dir'/'$result->{test}'/org/apache/commons/lang/enum/' | xargs sed -i'.bak' 's/\\.enum;/\\.oldenum;/'", "Rename enum package in test") or die;
        Utils::exec_cmd("cd $work_dir/$result->{test}/org/apache/commons/lang && mv enum oldenum", "Move enum package in test") or die;
    }

    # Check whether ant build file exists
    unless (-e "$work_dir/build.xml") {
        my $build_files_dir = "$PROJECTS_DIR/$PID/build_files/$revision_id";
        if (-d "$build_files_dir") {
            Utils::exec_cmd("cp -r $build_files_dir/* $work_dir", "Copy generated Ant build file") or die;
        }
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
