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

Project::JacksonXml.pm -- L<Project> submodule for jackson-dataformat-xml.

=head1 DESCRIPTION

This module provides all project-specific configurations and subroutines for the
jackson-dataformat-xml project.

=cut
package Project::JacksonXml;

use strict;
use warnings;

use Constants;
use Vcs::Git;
use File::Copy;

our @ISA = qw(Project);
my $PID  = "JacksonXml";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "jackson-dataformat-xml";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs);
}

#
# Post-checkout tasks include, for instance, providing cached build files,
# fixing compilation errors, etc.
#
sub _post_checkout {
    my ($self, $rev_id, $work_dir) = @_;
    my $vid = $self->{_vcs}->lookup_vid($rev_id);

    my $project_dir = "$PROJECTS_DIR/$self->{pid}";
    # Check whether ant build file exists
    unless (-e "$work_dir/build.xml") {
        my $build_files_dir = "$PROJECTS_DIR/$PID/build_files/$rev_id";
        if (-d "$build_files_dir") {
            Utils::exec_cmd("cp -r $build_files_dir/* $work_dir", "Copy generated Ant build file") or die;
        }
    }

    if (-e $work_dir."/pom.xml") {

        # The following edits to pom.xml have no effect on running test_verify_bugs.sh; they are needed only to ensure
        # that if you run 'mvn ant:ant' by hand, it will generate the same maven build files as the checked in versions.

        # copy to .orig because fix_dependency_urls over writes .bak
        copy($work_dir."/pom.xml", $work_dir."/pom.xml".'.orig');
        if ($vid == 1) {
            system("sed -i.bak s/rc4-SNAPSHOT/rc3/g \"$work_dir/pom.xml\"");
        }
        if ($vid == 5) {
            system("sed -i.bak s/2.9.6-SNAPSHOT/2.9.6/g \"$work_dir/pom.xml\"");
        }
        if ($vid == 6) {
            system("sed -i.bak s/2.9.8-SNAPSHOT/2.9.8/g \"$work_dir/pom.xml\"");
        }

        # Add a missing dependency
        open(IN, '<'."$work_dir"."/pom.xml") or die $!;

        # Read the content of the file into an array
        my @lines = <IN>;
        close(IN);

        # We want to find this dependency block:
        #   <dependency>
        #     <groupId>com.fasterxml.woodstox</groupId>
        #     <artifactId>woodstox-core</artifactId>
        #     <version>5.0.1</version>
        #     <scope>test</scope>
        #   </dependency>
        # and insert this block after it:
        #   <dependency>
        #     <groupId>javax.xml.bind</groupId>
        #     <artifactId>jaxb-api</artifactId>
        #     <version>2.3.0</version>
        #     <scope>test</scope>
        #   </dependency>

        # Pattern to search for - appears to be unique.
        my $pattern = 'com.fasterxml.woodstox';

        # Find the insert location based on the pattern
        my $insert_position = 0;
        foreach my $i (0 .. $#lines) {
            if ($lines[$i] =~ /$pattern/) {
                $insert_position = $i + 5;  # Insert after the </dependency>
                last;
            }
        }

        # Add lines at the specified location
        splice @lines, $insert_position, 0, (
            "    <dependency>\n",
            "      <groupId>javax.xml.bind</groupId>\n",
            "      <artifactId>jaxb-api</artifactId>\n",
            "      <version>2.3.0</version>\n",
            "      <scope>test</scope>\n",
            "    </dependency>\n"
        );

        # Write the modified content back to the file
        open(OUT, '>'."$work_dir"."/pom.xml") or die $!;
        print OUT @lines;
        close(OUT);
    }
    # End of code to modify pom.xml.

    # Copy generated file into place
    my $version = "UNKNOWN";

    open(IN,'<'."$work_dir/maven-build.properties") or die $!;
    while(my $line = <IN>) {
        if ($line =~ /maven\.build\.finalName/) {
            chomp($line);  # deal with no "-SNAPSHOT" at end of line
            my @words = split /-/, $line;
            $version = $words[3];
        }
    } 
    close(IN);

    if ($version ne "UNKNOWN"){
        copy($project_dir."/generated_sources/".$version."/PackageVersion.java", $work_dir."/src/main/java/com/fasterxml/jackson/dataformat/xml/PackageVersion.java");
    }
}

#
# This subroutine is called by the bug-mining framework for each revision during
# the initialization of the project. Example uses are: converting and caching
# build files or other time-consuming tasks, whose results should be cached.
#
sub initialize_revision {
    my ($self, $rev_id, $vid) = @_;
    $self->SUPER::initialize_revision($rev_id);

    my $work_dir = $self->{prog_root};
    my $result = {src=>"src/main/java", test=>"src/test/java"};

    $self->_add_to_layout_map($rev_id, $result->{src}, $result->{test});
    $self->_cache_layout_map(); # Force cache rebuild
}

1;
