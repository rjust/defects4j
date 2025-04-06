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

Project::Mockito.pm -- L<Project> submodule for mockito.

=head1 DESCRIPTION

This module provides all project-specific configurations and methods for the
mockito project.

=cut
package Project::Mockito;

use strict;
use warnings;

use Constants;
use Vcs::Git;

our @ISA = qw(Project);
my $PID  = "Mockito";

sub new {
    @_ == 1 or die $ARG_ERROR;
    my ($class) = @_;

    my $name = "mockito";
    my $vcs  = Vcs::Git->new($PID,
                             "$REPO_DIR/$name.git",
                             "$PROJECTS_DIR/$PID/$BUGS_CSV_ACTIVE",
                             \&_post_checkout);

    return $class->SUPER::new($PID, $name, $vcs);
}

sub _post_checkout {
    my ($self, $rev_id, $work_dir) = @_;

    # Fix Mockito's test runners

    my $bid = Utils::get_bid($work_dir);

    # TODO: Testing for bids/vids is super brittle! Find a better way to determine
    # whether a test class needs to be patched, or provide a patch for each
    # affected revision id.
    my $mockito_junit_runner_patch_file = "$PROJECTS_DIR/$PID/mockito_test_runners.patch";
    if ($bid == 16 || $bid == 17 || ($bid >= 34 && $bid <= 38)) {
        $self->apply_patch($work_dir, "$mockito_junit_runner_patch_file")
                or confess("Couldn't apply patch ($mockito_junit_runner_patch_file): $!");
    }

    # only bid with release notes and doesn't compile with newer Gradle
    if ($bid == 21) {
        system("rm -rf $work_dir/buildSrc/src/main/groovy/org/mockito/release/notes");
        system("rm -rf $work_dir/buildSrc/src/test/groovy/org/mockito/release/notes");
        Utils::sed_cmd("/apply.from:..gradle.release.gradle./d", "$work_dir/build.gradle");
    }

    # Change Url to Gradle distribution
    my $prop = "$work_dir/gradle/wrapper/gradle-wrapper.properties";
    my $lib_dir = "$BUILD_SYSTEMS_LIB_DIR/gradle/dists";

    # Modify the Gradle properties file, if it exists.
    if (open(PROP, "<$prop")) {
        my @tmp;
        while (<PROP>) {
            if (/(distributionUrl=).*\/(gradle-2.*)/) {
                s/(distributionUrl=).*\/(gradle-.*)/$1file\\:$lib_dir\/gradle-2.2.1-all.zip/g;
            } else {
                s/(distributionUrl=).*\/(gradle-.*)/$1file\\:$lib_dir\/gradle-1.12-bin.zip/g;
            }
            push(@tmp, $_);
        }
        close(PROP);
    
        # Update properties file
        open(OUT, ">$prop") or die "Cannot write properties file";
        print(OUT @tmp);
        close(OUT);
    
        # Disable the Gradle daemon
        if (-e "$work_dir/gradle.properties") {
            system("sed -i.bak s/org.gradle.daemon=true/org.gradle.daemon=false/g \"$work_dir/gradle.properties\"");
        }
    
        # Enable local repository
        system("find $work_dir -type f -name \"build.gradle\" -exec sed -i.bak 's|jcenter()|maven { url \"$BUILD_SYSTEMS_LIB_DIR/gradle/deps\" }\\\n maven { url \"https://jcenter.bintray.com/\" }\\\n|g' {} \\;");
    }

    # Add Major's runtime package to the bnd config
    if (-e "$work_dir/conf/mockito-core.bnd") {
      #Utils::sed_cmd("/Import-Package.*/a \\                major.mutation\.\*;resolution:=optional, \\\\\\\\ ", "$work_dir/conf/mockito-core.bnd");
    }

    if (-e "$work_dir/gradle") {
        # gradle files require changes due to upgrade to gradle 7.6.4 needed to support Java 17
        Utils::sed_cmd("s/2.0.0/4.0.0/", "$work_dir/build.gradle");
        Utils::sed_cmd("/compileClasspath/d", "$work_dir/build.gradle");
        Utils::sed_cmd("/configurations.classpath.exclude/a \\ " .
                                                           "\\n" .
                                                           "\\    configurations.all { \\n" .
                                                           "\\        resolutionStrategy {\\n" .
                                                           "\\            force 'xml-apis:xml-apis:1.4.01'\\n" .
                                                           "\\            force 'com.ibm.icu:icu4j:3.4.4'\\n" .
                                                           "\\        }\\n" .
                                                           "\\    }", "$work_dir/build.gradle");
        Utils::sed_cmd("/ provided\$/a \\    compileClasspath.extendsFrom(provided)\\n" .
                                     "\\    testCompile.extendsFrom(provided)", "$work_dir/build.gradle");
        Utils::sed_cmd("s/compile /implementation /", "$work_dir/build.gradle");
        Utils::sed_cmd("s/testCompile /testImplementation /", "$work_dir/build.gradle");
        Utils::sed_cmd("s/testRuntime /testRuntimeClasspath /", "$work_dir/build.gradle");
        Utils::sed_cmd("/task wrapper/,+2d", "$work_dir/build.gradle");
        Utils::sed_cmd("/junit:junit/a \\    implementation group: 'junit', name: 'junit', version: '4.13.2'\\n" .
                                     "\\    implementation 'org.hamcrest:hamcrest-library:1.3'", "$work_dir/build.gradle");

        Utils::sed_cmd("s/gradle-1.12-bin/gradle-7.6.4-bin/", "$work_dir/gradle/wrapper/gradle-wrapper.properties");
        Utils::sed_cmd("s/gradle-2.2.1-all/gradle-7.6.4-bin/", "$work_dir/gradle/wrapper/gradle-wrapper.properties");

        if (-e "$work_dir/buildSrc") {
          Utils::sed_cmd("s/0.7-groovy-1.8/2.0-groovy-3.0/", "$work_dir/buildSrc/build.gradle");
          Utils::sed_cmd("s/0.7-groovy-2.0/2.0-groovy-3.0/", "$work_dir/buildSrc/build.gradle");
          Utils::sed_cmd("s/testCompile/testImplementation/", "$work_dir/buildSrc/build.gradle");
          Utils::sed_cmd("s/compile/implementation/", "$work_dir/buildSrc/build.gradle");
          Utils::sed_cmd("s/groovy-all/org.codehaus.groovy/", "$work_dir/buildSrc/build.gradle");
          Utils::sed_cmd("/nodep:2.2.2/a \\    testImplementation group: 'junit', name: 'junit', version: '4.13.2'", "$work_dir/buildSrc/build.gradle");
        }

        if (-e "$work_dir/gradle/javadoc.gradle") {
          Utils::sed_cmd("s/classpath = configurations/\\/\\/classpath = configurations/", "$work_dir/gradle/javadoc.gradle");
        }

        Utils::sed_cmd("s/testCompile/testImplementation/", "$work_dir/subprojects/extTest/extTest.gradle");

        Utils::sed_cmd("/uploadArchives/,+7d", "$work_dir/subprojects/testng/testng.gradle");
        Utils::sed_cmd("s/testCompile/testImplementation/", "$work_dir/subprojects/testng/testng.gradle");
        Utils::sed_cmd("s/compile/implementation/", "$work_dir/subprojects/testng/testng.gradle");
        Utils::sed_cmd("s/\'maven\'/\'maven-publish\'/", "$work_dir/subprojects/testng/testng.gradle");

        # Set default Java target to 7.
        Utils::sed_cmd("s/sourceCompatibility = 1\.[1-6]/sourceCompatibility=1.7/", "$work_dir/build.gradle");
        Utils::sed_cmd("s/targetCompatibility = 1\.[1-6]/targetCompatibility=1.7/", "$work_dir/build.gradle");
    }
    if (-e "$work_dir/build.xml") {
        # some gradle builds use build.xml as well
        Utils::sed_cmd("s/source=\\\"1\.[1-6]\\\"/source=\\\"1.7\\\"/", "$work_dir/build.xml");
        Utils::sed_cmd("s/target=\\\"1\.[1-6]\\\"/target=\\\"1.7\\\"/", "$work_dir/build.xml");
    }

    # Fix compilation errors if necessary
    my $compile_errors = "$PROJECTS_DIR/$self->{pid}/compile-errors/";
    opendir(DIR, $compile_errors) or die "Could not find compile-errors directory.";
    my @entries = readdir(DIR);
    closedir(DIR);
    foreach my $file (@entries) {
        if ($file =~ /-(\d+)-(\d+)(.optional)?.diff/) {
            my $opt = $3;
            if ($bid >= $1 && $bid <= $2) {
                # many of the Mockito source files are in DOS/Windows format
                # convert to unix format before trying to apply the patch
                open my $patch, '<', "$compile_errors/$file";
                my $firstline = <$patch>;
                close $patch;
                (my $filename = $firstline) =~ s/^.............//;
                $filename =~ s/ .*//;
                Utils::exec_cmd("dos2unix -q $work_dir/$filename", "run dos2unix on patch target");
                my $ret = $self->apply_patch($work_dir, "$compile_errors/$file", $opt);
                if (!$ret && !$opt) {
                    confess("Couldn't apply patch ($file): $!");
                }
            }
        }
    }
}

sub determine_layout {
    @_ == 2 or die $ARG_ERROR;
    my ($self, $rev_id) = @_;
    my $work_dir = $self->{prog_root};
    if (-e "$work_dir/src/main/java") {
        return {src=>"src/main/java", test=>"src/test/java"};
    } elsif(-e "$work_dir/src") {
        return {src=>"src", test=>"test"};
    } else {
        die "Unknown directory layout";
    }
}

sub _ant_call {
    @_ >= 2 or die $ARG_ERROR;
    my ($self, $target, $option_str, $log_file) =  @_;

    # By default gradle uses $HOME/.gradle, which causes problems when multiple
    # instances of gradle run at the same time.
    #
    # TODO: Extract all exported environment variables into a user-visible
    # config file.
    $ENV{'GRADLE_USER_HOME'} = "$self->{prog_root}/$GRADLE_LOCAL_HOME_DIR";
    return $self->SUPER::_ant_call($target, $option_str, $log_file);
}

1;
