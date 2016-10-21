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

Utils.pm -- some useful helper subroutines.

=head1 DESCRIPTION

This module provides general helper subroutines such as parsing config or data files.

=cut
package Utils;

use warnings;
use strict;

use File::Basename;
use Cwd qw(abs_path);
use Carp qw(confess);

use Constants;

my $dir = dirname(abs_path(__FILE__));

=pod

=head1 Static subroutines

  Utils::get_tmp_dir([tmp_root])

Returns F<C<tmp_root>/C<scriptname>_C<process_id>_C<timestamp>>

This directory is unique in a local file system. The root directory to be used
can be specified with C<tmp_root> (optional).
The default is L<D4J_TMP_DIR|Constants>.

=cut
sub get_tmp_dir {
    my $tmp_root = shift // $D4J_TMP_DIR;
    return "$tmp_root/" . basename($0) . "_" . $$ . "_" . time;
}

=pod

  Utils::get_abs_path(dir)

Returns the absolute path to the directory F<dir>.

=cut
sub get_abs_path {
    @_ == 1 or die $ARG_ERROR;
    my $dir = shift;
    # Remove trailing slash
    $dir =~ s/^(.+)\/$/$1/;
    return abs_path($dir);
}

=pod

  Utils::get_failing_tests(test_result_file)

Determines all failing test classes and test methods in F<test_result_file>,
which may contain arbitrary lines. A line indicating a test failure matches the
following pattern: C</--- ([^:]+)(::([^:]+))?/>.

This subroutine returns a reference to a hash that contains three keys (C<classes>,
C<methods>, and C<asserts>), which map to lists of failing tests:

=over 4

  {classes} => [org.foo.Class1 org.bar.Class2]
  {methods} => [org.foo.Class3::method1 org.foo.Class3::method2]
  {asserts} => {org.foo.Class3::method1} => 4711

=back

=cut
sub get_failing_tests {
    @_ == 1 or die $ARG_ERROR;
    my $file_name = shift;

    my $list = {
        classes => [],
        methods => [],
        asserts => {}
    };
    open FILE, $file_name or die "Cannot open test result file ($file_name): $!";
    my @lines = <FILE>;
    close FILE;
    for (my $i=0; $i <= $#lines; ++$i) {
        local $_ = $lines[$i];
        chomp;
        /--- ([^:]+)(::([^:]+))?/ or next;
        my $class = $1;
        my $method= $3;
        if (defined $method) {
            push(@{$list->{methods}}, "${class}::$method");
            # Read first line of stack trace to determine the failure reason.
            my $reason = $lines[$i+1];
            if (defined $reason and $reason =~ /junit.framework.AssertionFailedError/) {
                $class =~ /(.*\.)?([^.]+)/ or die "Couldn't determine class name: $class!";
                my $classname = $2;
                ++$i;
                while ($lines[$i] !~ /---/) {
                    if ($lines[$i] =~ /junit\./) {
                        # Skip junit entries in the stack trace
                        ++$i;
                    } elsif ($lines[$i] =~ /$classname\.java:(\d+)/) {
                        # We found the right entry in the stack trace
                        my $line = $1;
                        $list->{asserts}->{"${class}::$method"} = $line;
                        last;
                    } else {
                        # The stack trace isn't what we expected -- give up and continue
                        # with the next triggering test
                        last;
                    }
                }
            }
        } else {
            push(@{$list->{classes}}, $class);
        }
    }
    return $list;
}

=pod

  Utils::has_failing_tests(result_file)

Returns 1 if the provided F<result_file> lists any failing test classes or
failing test methods. Returns 0 otherwise.

=cut
sub has_failing_tests {
    @_ == 1 or die $ARG_ERROR;
    my $file_name = shift;

    my $list = get_failing_tests($file_name) or die "Could not parse file";
    my @fail_methods = @{$list->{methods}};
    my @fail_classes = @{$list->{classes}};

    return 1 unless (scalar(@fail_methods) + scalar(@fail_classes)) == 0;

    return 0;
}

=pod

  Utils::write_config_file(filename, config_hash)

Writes all key-value pairs of C<config_hash> to a config file named F<filename>.
Existing entries are overridden and missing entries are added to the config file
-- all existing but unmodified entries are preserved.

=cut
sub write_config_file {
    @_ == 2 or die $ARG_ERROR;
    my ($file, $hash) = @_;
    my %newconf = %{$hash};
    if (-e $file) {
        my $oldconf = read_config_file($file);
        for my $key (keys %{$oldconf}) {
            $newconf{$key} = $oldconf->{$key} unless defined $newconf{$key};
        }
    }
    open(OUT, ">$file") or die "Cannot create config file ($file): $!";
    print(OUT "#File automatically generated by Defects4J\n");
    for my $key(sort(keys(%newconf))) {
        print(OUT "$key=$newconf{$key}\n");
    }
    close(OUT);
}

=pod

  Utils::read_config_file(filename)

Read all key-value pairs of the config file named F<filename>. Format:
C<key=value>.  Returns a hash containing all key-value pairs on success,
C<undef> otherwise.

=cut
sub read_config_file {
    @_ == 1 or die $ARG_ERROR;
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

=pod

  Utils::check_vid(vid)

Check whether C<vid> represents a valid version id, i.e., matches \d+[bf].

=cut
sub check_vid {
    @_ == 1 or die $ARG_ERROR;
    my $vid = shift;
    $vid =~ /^(\d+)([bf])$/ or confess("Wrong version_id: $vid -- expected \\d+[bf]!");
    return {valid => 1, bid => $1, type => $2};
}

=pod

  Utils::tag_prefix(pid, bid)

Returns the Defects4J prefix for tagging a buggy or fixed program version.

=cut
sub tag_prefix {
    @_ == 2 or die $ARG_ERROR;
    my ($pid, $bid) = @_;
    return "D4J_" . $pid . "_" . $bid . "_";
}

=pod

  Utils::exec_cmd(cmd, description [, log_ref])

Runs a system command and indicates whether it succeeded or failed. This
subroutine captures the output (F<stdout>) of the command and only logs that
output to F<stderr> if the command fails or if C<Constants::DEBUG> is set to
true. This subroutine converts exit codes into boolean values, i.e., it returns
C<1> if the command succeeded and C<0> otherwise. If the optional reference
C<log_ref> is provided, the captured output is stored in that variable.

=cut
sub exec_cmd {
    @_ >= 2 or die $ARG_ERROR;
    my ($cmd, $descr, $log_ref) = @_;
    print(STDERR substr($descr . '.'x75, 0, 75), " ");
    my $log = `$cmd`; my $ret = $?;
    $$log_ref = $log if defined $log_ref;
    if ($ret!=0) {
        print(STDERR "FAIL\n$log");
        print(STDERR "Executed command: $cmd\n");
        return 0;
    }
    print(STDERR "OK\n");
    # Upon success, only print log messages if debugging is enabled
    print(STDERR "Executed command: $cmd\n") if $DEBUG;
    print(STDERR $log) if $DEBUG;

    return 1;
}

=pod

  Utils::get_all_test_suites(suite_dir, pid [, vid])

Determines all Defects4J test suite archives that exist in F<suite_dir> and that
match the given project id (C<pid>) and version id (C<vid>). Note that C<vid> is
optional.

This subroutine returns a reference to a hierarchical hash that holds all
matching test suite archives:

=over 4

  $result->{vid}->{suite_src}->{test_id}->{file_name}

=back

=cut
sub get_all_test_suites {
    @_ >= 2 or die $ARG_ERROR;
    my ($suite_dir, $pid, $vid) = @_;
    my %test_suites = ();
    my $count = 0;
    opendir(DIR, $suite_dir) or die "Cannot open directory: $suite_dir!";
        my @entries = readdir(DIR);
    closedir(DIR);
    foreach (@entries) {
        next unless /^$pid-(\d+[bf])-([^\.]+)(\.(\d+))?.tar.bz2$/;
        my $archive_vid = $1;
        my $archive_suite_src = "$2";
        my $archive_test_id = $4 // 1;

        # Only hash test suites for target vid, if provided
        next if defined $vid and $vid ne $archive_vid;

        # Init hash if necessary
        $test_suites{$archive_vid} = {}
                unless defined $test_suites{$archive_vid};
        $test_suites{$archive_vid}->{$archive_suite_src} = {}
                unless defined $test_suites{$archive_vid}->{$archive_suite_src};

        # Save archive name for current test id
        $test_suites{$archive_vid}->{$archive_suite_src}->{$archive_test_id} = $_;

        ++$count;
    }
    print(STDERR "Found $count test suite archive(s)") if $DEBUG;
    return \%test_suites;
}

=pod

  Utils::extract_test_suite(test_suite, test_dir)

Extracts an archive of an external test suite (F<test_suite>) into a given test directory
(F<test_dir>). The directory F<test_dir> is created if it doesn't exist.
This subroutine returns 1 on success, 0 otherwise.

=cut
sub extract_test_suite {
    @_ == 2 or die $ARG_ERROR;
    my ($test_suite, $test_dir) = @_;
    my %test_suites = ();
    unless (-e $test_suite) {
        print(STDERR "Test suite archive not found: $test_suite\n");
        return 0;;
    }
    # Extract external test suite into test directory
    exec_cmd("mkdir -p $test_dir && rm -rf $test_dir/* && tar -xjf $test_suite -C $test_dir",
            "Extract test suite") or return 0;
    return 1;
}

1;
