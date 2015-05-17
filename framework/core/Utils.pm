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

Utils.pm -- Provides helper functions.

=head1 DESCRIPTION

This module provides general helper functions such as parsing config or data files.

=cut
package Utils;

use warnings;
use strict;

use Constants;
use File::Basename;
use Cwd qw(abs_path);
use Fcntl qw(:flock SEEK_END);

my $dir = dirname(abs_path(__FILE__));

=pod

=head1 HELPER FUNCTIONS:

=over 4

=item B<get_tmp_dir> C<get_tmp_dir([tmp_root])>

Returns the path to a unique (local) temporary directory:
B<"tmp_root"/"script_name"_"process_id"_"timestamp">

The path is unique w.r.t. a local file system. The root directory to be used can
be specified with C<tmp_root> (optional) -- the default is F</tmp>.

=cut
sub get_tmp_dir {
    my $tmp_root = shift // $ENV{ALT_TMP} // "/tmp";
    return "$tmp_root/" . basename($0) . "_" . $$ . "_" . time;
}

=pod

=item B<get_abs_path> C<get_abs_path(dir)>

Returns the absolute path to the directory F<dir>.

=cut
sub get_abs_path {
    @_ == 1 or die "Invalid number of arguments!";
    my $dir = shift;
    # Remove trailing slash
    $dir =~ s/^(.+)\/$/$1/;
    return abs_path($dir);
}

=pod


=pod

=item B<get_failing_tests> C<get_failing_tests(result_file)>

Returns a reference to a hash of references to lists with failing test classes
and methods found in the C<result_file>. The C<result_file> may contain
arbitrary lines -- this method only considers lines that match the pattern:
B</--- ([^:]+)(::([^:]+))?/>.

The data structure of the returned hash reference looks like:

{classes} => [org.foo.Class1 org.bar.Class2]

{methods} => [org.foo.Class3::method1 org.foo.Class3::method2]

=cut
sub get_failing_tests {
    @_ == 1 or die "Invalid number of arguments!";
    my $file_name = shift;

    my $list = {
        classes => [],
        methods => []
    };
    open FILE, $file_name or die "Cannot open result file: $!";
    while (<FILE>) {
        chomp;
        /--- ([^:]+)(::([^:]+))?/ or next;
        my $class = $1;
        my $method= $3;
        if (defined $method) {
            push(@{$list->{methods}}, "${class}::$method");
        } else {
            push(@{$list->{classes}}, $class);
        }
    }
    close FILE;
    return $list;
}

=pod

=item B<has_failing_tests> C<has_failing_tests(result_file)>

Returns 1 if the provided F<result_file> lists any failing test classes or
failing test methods. Returns 0 otherwise.

=cut
sub has_failing_tests {
    @_ == 1 or die "Invalid number of arguments!";
    my $file_name = shift;

    my $list = get_failing_tests($file_name) or die "Could not parse file";
    my @fail_methods = @{$list->{methods}};
    my @fail_classes = @{$list->{classes}};

    return 1 unless (scalar(@fail_methods) + scalar(@fail_classes)) == 0;

    return 0;
}

=pod

=item B<parse_machines> C<parse_machines(filename)>

Returns an array containing pairs of (machine_name, directory)
in the file specified by C<filename>

=cut
sub parse_machines {
    my $machines_file = shift;

    open FH, $machines_file;
    my @machines = ();
    for (<FH>) {
        m[(.*),(.*)/(.*?)$];
        push @machines, ([$1, $2]);
    }
    close FH;
    @machines;
}

=pod

=item B<write_config_file> C<write_config_file(filename, config_hash)>

Writes all key-value pairs of C<config_hash> to a config file named
C<filename>. Existing entries are overridden and missing entries are added
to the config file -- all existing but unmodified entries are preserved.

=cut
sub write_config_file {
    my ($file, $hash) = @_;
    my %newconf = %{$hash};
    if (-e $file) {
        my $oldconf = read_config_file($file);
        for my $key (keys %{$oldconf}) {
            $newconf{$key} = $oldconf->{$key} unless defined $newconf{$key};
        }
    }
    open(OUT, ">$file") or die "Cannot create config file ($file): $!";
    print(OUT "#Config file generated by Defects4J\n");
    for my $key(keys(%newconf)) {
        print(OUT "$key=$newconf{$key}\n");
    }
    close(OUT);
}

=item B<read_config_file> C<read_config_file(filename)>

Read all key-value pairs of the config file C<filename>. Format: key=value.
Returns a hash containing all key-value pairs on success, undef otherwise.

=back

=cut
sub read_config_file {
    my $file = shift;
    if (!open(IN, "<$file")) {
        print(STDERR "Cannot open config file ($file): $!\n");
        return undef;
    }
    my $hash = {};
    while(<IN>) {
        # Skip comments and empty lines
        next if /^\s*#/;
        next if /^\s*$/;
        chomp;
        # Read key value pair and remove white spaces
        my ($key, $val) = split /=/;
        $key =~ s/ //;
        $val =~ s/ //;
        $hash->{$key} = $val;
    }
    close(IN);
    return $hash;
}

=item B<maven_to_ant> C<maven_to_and(patch_file, work_dir, out_dir)>

Generates a C<build.xml> from a C<pom.xml> that exists in C<work_dir>,
and saves the output to C<out_dir>.

Before invoking C<mvn ant:ant> to do this conversion,
this method applies C<patch_file> to C<build.xml>.

This method causes program crash on failure.

=cut
sub maven_to_ant {
    my ($patch_file, $work_dir, $out_dir) = @_;
    my $log = `cd $work_dir && mvn ant:ant 2>&1 \\
               && patch build.xml $patch_file 2>&1 \\
               && mkdir -p $out_dir 2>&1 \\
               && cp maven-build.* $out_dir 2>&1 \\
               && cp build.xml $out_dir 2>&1`;

    my $ret = $?;
    if ($ret==0) {
        print "OK\n";
    } else {
        print "FAIL\n$log"; die;
    }

    # Check whether build.classpath and build.test.classpath exist
    system("grep 'path id=\"build.classpath\"' $out_dir/maven-build.xml >/dev/null") == 0
        or die "Could not find build.classpath";

    system("grep 'path id=\"build.test.classpath\"' $out_dir/maven-build.xml >/dev/null") == 0
       or die "Could not find build.test.classpath";
}

=item B<append_to_file_unless_matches> C<append_to_file_unless_matches(file, string, regexp)>

This utility method appends C<string> to C<file>, unless C<file>
contains a line that matches C<regexp>.

This is done in a way that is safe for multiple processes accessing
C<file> by acquiring flocks.

=cut
sub append_to_file_unless_matches {
    my ($file, $string, $includes) = @_;
    @_ == 3 or die $ARG_ERROR;

    open my $fh, ">>$file" or die "Cannot open file for appending $file: $!";
    flock ($fh, LOCK_EX) or die "Cannot exclusively lock  $file: $!";
    open my $fh_in, "<$file" or die "Cannot open file for reading $file: $!";
    my $seen = 0;
    while (my $line = <$fh_in>) {
        if ($line =~ /$includes/) {
            $seen = 1;
            last;
        }
    }
    close $fh_in;
    unless ($seen) {
        seek ($fh, 0, SEEK_END) or die "Cannot seek: $!"; # seek if someone appended while we were waiting
        print $fh $string;
    }
    close $fh;
    return $seen == 1 ? 0 : 1;
}
