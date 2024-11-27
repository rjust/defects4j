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

Utils.pm -- some useful helper subroutines.

=head1 DESCRIPTION

This module provides general helper subroutines such as parsing config or data files.

=cut

package Utils;

use warnings;
use strict;

use File::Basename;
use File::Spec;
use Cwd qw(abs_path);
use Carp qw(confess);
use Fcntl qw< LOCK_EX SEEK_END >;
use String::Interpolate qw(safe_interpolate);

use Constants;

my $dir = dirname(abs_path(__FILE__));

=pod

=head2 General subroutines

=over 4

=item C<Utils::exec_cmd(cmd, description [, log_ref])>

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
        print(STDERR "FAIL\n");
        print(STDERR "Executed command: $cmd\n");
        print(STDERR "$log");
        return 0;
    }
    print(STDERR "OK\n");
    # Upon success, only print log messages if debugging is enabled
    print(STDERR "Executed command: $cmd\n") if $DEBUG;
    print(STDERR $log) if $DEBUG;

    return 1;
}

=pod

=item C<Utils::get_tmp_dir([tmp_root])>

Returns F<C<tmp_root>/C<scriptname>_C<process_id>_C<timestamp>>

This directory is unique in a local file system. The root directory to be used
can be specified with C<tmp_root> (optional).
The default is L<D4J_TMP_DIR|Constants>.

=cut

sub get_tmp_dir {
    my ($tmp_root) = @_;
    $tmp_root //= $D4J_TMP_DIR;
    return "$tmp_root/" . basename($0) . "_" . $$ . "_" . time;
}

=pod

=item C<Utils::get_abs_path(dir)>

Returns the absolute path to the directory F<dir>.

=cut

sub get_abs_path {
    @_ == 1 or die $ARG_ERROR;
    my ($dir) = @_;
    # Remove trailing slash
    $dir =~ s/^(.+)\/$/$1/;
    return File::Spec->rel2abs($dir);
}

=pod

=item C<Utils::get_dir(file)>

Returns the directory of the absolute path of F<file>.

=cut

sub get_dir {
    @_ == 1 or die $ARG_ERROR;
    my ($path) = @_;
    my ($volume,$dir,$file) = File::Spec->splitpath($path);
    return get_abs_path($dir);
}

=pod

=item C<Utils::append_to_file_unless_matches(file, string, regexp)>

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

=pod

=item C<Utils::files_in_commit(repo_dir, commit)>

Returns an array of files changed in C<commit> in the git repository F<repo_dir>.

=cut

sub files_in_commit {
    my ($repo_dir, $commit) = @_;
    my @files = "cd $repo_dir; git diff-tree --no-commit-id --name-only -r $commit";
    chomp @files;
    return @files;
}

=pod

=item C<Utils::print_entry(key, val)>

Print a key-value pair for a single-line value. For
instance, C<print_entry("SHELL", "/bin/bash")> will print the following to
F<stdout>:

    SHELL................./bin/bash

=cut

sub print_entry {
    @_ >= 2 || die $ARG_ERROR;
    my ($key, $val, $val_start_col) = @_;
    $val =~ s/^\s+|\s+$//g;
    if (! defined $val_start_col) {
        $val_start_col = 30;
    }
    my $num_seps = $val_start_col - length($key);
    print(STDERR "$key" . ('.' x $num_seps) . "${val}\n");

}

=pod

=item C<Utils::print_multiline_entry(key, val [, vals...])>

Print a key-value pair for a multi-line value. For
instance, C<print_multiline_entry("Java Version", `java -version`)> will print
something like the following to F<stderr>:

    Java Version:
      openjdk version "1.8.0_232"
      OpenJDK Runtime Environment (AdoptOpenJDK)(build 1.8.0_232-b09)
      OpenJDK 64-Bit Server VM (AdoptOpenJDK)(build 25.232-b09, mixed mode)

=cut

sub print_multiline_entry {
    @_ >= 2 || die $ARG_ERROR;
    my ($key, @lines) = @_;
    print(STDERR "$key:\n  " . join("  ", @lines));
}

=pod

=item C<Utils::print_environment_var(var)>

Lookup an environment variable's value and print it to F<stderr>.

=cut

sub print_environment_var {
    @_ == 1 || die $ARG_ERROR;
    my ($key) = @_;
    my $val = $ENV{$key} // "(none)";
    print_entry ($key, $val);
}

=pod

=item C<Utils::print_env>

Print relevant environment variables to F<stderr>.

=cut

sub print_env {
    print(STDERR "-"x80 . "\n");
    print(STDERR "                     Defects4j Execution Environment \n");
    print(STDERR "-"x80 . "\n");
    # General environment
    print_environment_var("PWD");
    print_environment_var("SHELL");
    print_environment_var("TZ");

    # Java environment
    print_environment_var("JAVA_HOME");
    print_entry("Java Exec", `which java`);
    print_entry("Java Exec Resolved", `realpath \$(which java)`);
    print_multiline_entry("Java Version", `java -version 2>&1`);

    # VCS
    print_entry("Git version", `git --version`);
    print_entry("SVN version", `svn --version --quiet`);
    print_entry("Perl version", $^V);
    print(STDERR "-"x80 . "\n");
}

=pod

=item C<Utils::print_perl_call_stack>

Print the current Perl execution stack trace to F<stderr>.

=cut

sub print_perl_call_stack {
    my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash);
    my $i = 1;
    my @r;
    while (@r = caller($i)) {
        ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = @r;
        print(STDERR  "$filename:$line $subroutine\n");
        $i++;
    }
}

=pod

=item C<Utils::convert_file_encoding(file_name)>

Copies the original file to <file_name>.bak then converts
the encoding of file_name from iso-8859-1 to utf-8.

=cut

sub convert_file_encoding {
    @_ == 1 or die $ARG_ERROR;
    my ($file_name) = @_;
    if (-e $file_name){
        rename($file_name, $file_name.".bak");
        open(OUT, '>'.$file_name) or die $!;
        my $converted_file = `iconv -f iso-8859-1 -t utf-8 $file_name.bak`;
        print OUT $converted_file;
        close(OUT);
    }
}

=pod

=item C<Utils::sed_cmd(cmd_string, file_name)>

Uses sed with cmd_string to modify file_name.

=cut

sub sed_cmd {
    @_ == 2 || die $ARG_ERROR;
    my ($cmd_string, $file_name) = @_;

    print(STDERR "About to execute command: sed -i $cmd_string $file_name\n") if $DEBUG;

    # We ignore sed result as it is ok if command fails.
    chomp(my $uname = `uname -s`);
    if ($uname eq "Darwin" ) {
        `sed -i '' -e '$cmd_string' $file_name`;
    } else {
        `sed -i "$cmd_string" "$file_name"`;
    }
}

=pod

=item C<Utils::is_continuous_integration>

Returns true if this process is running under continuous integration.

=cut
sub is_continuous_integration {
  return (
    # Azure Pipelines
    defined $ENV{"AZURE_HTTP_USER_AGENT"}
    || defined $ENV{"SYSTEM_PULLREQUEST_TARGETBRANCH"}
    # CircleCI
    || defined $ENV{"CIRCLE_COMPARE_URL"}
    # Travis CI
    || (defined $ENV{"TRAVIS"}
        && $ENV{"TRAVIS"} eq "true")
    );
}

=pod

=item C<Utils::fix_dependency_urls(build_file, pattern_file, multi_line)>

Parses the F<build_file> and applies the first matching pattern in the F<pattern_file>.

=cut
sub fix_dependency_urls {
    @_ == 3 || die $ARG_ERROR;
    my ($build_file, $pattern_file, $multi_line) = @_;

    open(IN, "<$build_file") or die("Cannot read the build file: $build_file");
    my @lines = <IN>;
    close(IN);

    open(IN, "<$pattern_file") or die("Cannot read pattern file: $pattern_file");
    my @patterns = <IN>;
    close(IN);

    # Read all regexes; skip comments
    my @regexes;
    foreach my $l (@patterns) {
        $l =~ /^\s*#/ and next;
        chomp($l);
        $l =~ /([^,]+),([^,]+)/ or die("Row in pattern file in wrong format: $l (expected: <find>,<replace>)");
        my ($find, $repl) = split(",", $l);
        if (! $multi_line) {
            push(@regexes, [qr/$find/, $repl]);
        } else {
            print(STDERR "Multi-line matching enabled.\n");
            push(@regexes, [qr/$find/ms, $repl]);
            # Replace the list of lines with a single entry, if multi-line match
            # is enabled. This allows us to use the same iteration over all
            # "lines" below.
            @lines = join("", @lines);
        }
    }

    # Process the build file
    my $modified = 0;
    for (my $i=0; $i<=$#lines; ++$i) {
        my $l = $lines[$i];
        foreach (@regexes) {
            if ($l =~ s/$$_[0]/safe_interpolate($$_[1])/eg) {
                unless($modified) {
                    exec_cmd("cp $build_file $build_file.bak", "Backing up build file: $build_file");
                    $modified = 1;
                }
                print(STDERR "Pattern matches in build file ($build_file): $$_[0]\n") if $DEBUG;
                $lines[$i] = $l;
                last;
            }
        }
    }

    # Update the build file if necessary
    if ($modified) {
        unlink($build_file);
        my $fix = IO::File->new(">$build_file") or die("Cannot overwrite build file: $!");
        print $fix @lines;
        $fix->flush();
        $fix->close();
    }
}

=pod

=back

=cut

################################################################################

=pod

=head2 Configuration

=over 4

=item C<Utils::write_config_file(filename, config_hash)>

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

=item C<Utils::read_config_file(filename [, key_separator])>

Read all key-value pairs of the config file named F<filename>. Format:
C<key=value>.  Returns a hash containing all key-value pairs on success,
C<undef> otherwise.

=cut

sub read_config_file {
    @_ >= 1 or die $ARG_ERROR;
    my ($file, $key_separator) = @_;
    $key_separator //= '=';

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
        my ($key, $val) = split /${key_separator}/;
        $key =~ s/ //;
        $val =~ s/ //;
        $hash->{$key} = $val;
    }
    close(IN);
    return $hash;
}

=pod

=item C<Utils::tag_prefix(pid, bid)>

Returns the Defects4J prefix for tagging a buggy or fixed program version.

=cut

sub tag_prefix {
    @_ == 2 or die $ARG_ERROR;
    my ($pid, $bid) = @_;
    return "D4J_" . $pid . "_" . $bid . "_";
}

=pod

=item C<Utils::bug_report_info(pid, vid)>

Returns the bug report ID and URL of a given project id C<pid> and version id
C<vid>. In case there is not any bug report ID/URL available for a specific
project id C<pid> and version id, it returns "NA".

=cut

sub bug_report_info {
    @_ == 2 or die $ARG_ERROR;
    my ($pid, $vid) = @_;

    my $bug_report_info = {id=>"NA", url=>"NA"};

    my $commit_db = "$PROJECTS_DIR/$pid/$BUGS_CSV_ACTIVE";
    open (IN, "<$commit_db") or die "Cannot open $commit_db file: $!";
    my $header = <IN>;
    while (<IN>) {
        chomp;
        /([^,]+),[^,]+,[^,]+,(.+),(.+)/ or next;
        if ($vid == $1) {
            $bug_report_info = {id=>$2, url=>$3};
            last;
        }
    }
    close IN;

    return $bug_report_info;
}

=pod

=item C<Utils::get_bid(work_dir)>

Returns the C<bid> (bug id) associated with the provided C<work_dir> (Defects4J
working directory). This function dies if the working directory does not exist
or is invalid (i.e., does not provide a Defects4J config file).

=cut

sub get_bid {
    @_ == 1 or die $ARG_ERROR;
    my ($work_dir) = @_;

    if (-e "$work_dir/$CONFIG") {
        my $config = Utils::read_config_file("$work_dir/$CONFIG");
        if (defined $config) {
            # Validate vid and extract corresponding bid
            my $bid = check_vid($config->{$CONFIG_VID})->{bid};
            return $bid;
        }
    }
    die "Invalid working directory! Cannot read: $work_dir/$CONFIG"
}

=pod

=back

=cut


################################################################################

=pod

=head2 Input validation

=over 4

=item C<Utils::check_vid(vid)>

Check whether C<vid> represents a valid version id, i.e., matches \d+[bf].

This subroutine terminates with an error message if C<vid> is not valid.
Otherwise, it returns a hash that maps C<bid> to the bug id that was parsed from
the provided C<vid>, and C<type> to the version type (C<b> or C<f>) that was
parsed from the provided C<vid>.

For instance, to check that this is a valid bug and extract the bug-id on
success, write:

  my bid = Utils::check_vid(vid)->{bid};

=cut

sub check_vid {
    @_ == 1 or die $ARG_ERROR;
    my ($vid) = @_;
    $vid =~ /^(\d+)([bf])$/ or confess("Wrong version_id: $vid -- expected \\d+[bf]!");
    return {valid => 1, bid => $1, type => $2};
}

=pod

=item C<Utils::ensure_valid_bid(pid, bid)>

Ensure C<bid> represents a valid bug-id in project C<pid>, terminating with a
detailed error message if not. A bug-id is valid for a project if the project
exists and the bug-id both exists in the project and is active.

=cut

sub ensure_valid_bid {
    @_ == 2 or die $ARG_ERROR;
    my ($pid, $bid) = @_;

    my $project_dir = "$PROJECTS_DIR/$pid";

    if ( ! -e "${project_dir}" ) {
        confess("Error: ${pid} is not a project id; for a list, see https://github.com/rjust/defects4j#the-projects\n");
    }

    if ( ! -e "${project_dir}/trigger_tests/${bid}" ) {
        confess("Error: ${pid}-${bid} is a not a bug id; for a list, see ${project_dir}/trigger_tests\n");
    }

    # Instantiate the project and get the list of all active bug ids
    my $project = Project::create_project($pid);
    my @bug_ids = $project->get_bug_ids;
    if ( ! grep( /^$bid$/, @bug_ids) ) {
        confess("Error: ${pid}-${bid} is a deprecated bug\n");
    }
}

=pod

=item C<Utils::ensure_valid_vid(pid, vid)>

Ensure C<vid> represents a valid version-id in project C<pid>, terminating with
a detailed error message if not. A version-id is valid for a project if the
project exists, the version-id is of the form C<d+[bf]>, and the underlying
bug-id, represented by the leading integer part of the version id, both exists
in the project and is active.

=cut

sub ensure_valid_vid {
    @_ == 2 or die $ARG_ERROR;
    my ($pid, $vid) = @_;
    my $bid = check_vid($vid)->{bid};
    ensure_valid_bid($pid, $bid);
}

=pod

=back

=cut

################################################################################

=pod

=head2 Test results and test suites

=over 4

=item C<Utils::has_failing_tests(test_result_file)>

Returns 1 if the provided F<test_result_file> lists any failing test classes or
failing test methods. Returns 0 otherwise.

=cut

sub has_failing_tests {
    @_ == 1 or die $ARG_ERROR;
    my ($file_name) = @_;

    my $list = get_failing_tests($file_name) or die "Could not parse file";
    my @fail_methods = @{$list->{methods}};
    my @fail_classes = @{$list->{classes}};

    return 1 unless (scalar(@fail_methods) + scalar(@fail_classes)) == 0;

    return 0;
}

=pod

=item C<Utils::get_failing_tests(test_result_file)>

Determines all failing test classes and test methods in F<test_result_file>,
which may contain arbitrary lines. A line indicating a test failure matches the
following pattern: C</--- ([^:]+)(::([^:]+))?/>.

This subroutine returns a reference to a hash that contains three keys (C<classes>,
C<methods>, and C<asserts>), which map to lists of failing tests:

  {classes} => [org.foo.Class1 org.bar.Class2]
  {methods} => [org.foo.Class3::method1 org.foo.Class3::method2]
  {asserts} => {org.foo.Class3::method1} => 4711

=cut

sub get_failing_tests {
    @_ == 1 or die $ARG_ERROR;
    my ($file_name) = @_;

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

=item C<Utils::get_all_test_suites(suite_dir, pid [, vid])>

Determines all Defects4J test suite archives that exist in F<suite_dir> and that
match the given project id (C<pid>) and version id (C<vid>). Note that C<vid> is
optional.

This subroutine returns a reference to a hierarchical hash that holds all
matching test suite archives:

  $result->{vid}->{suite_src}->{test_id}->{file_name}

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

=item C<Utils::extract_test_suite(test_suite, test_dir)>

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

=pod

=item C<Utils::clean_test_results(work_dir)>

Remove any old test results in the provided C<work_dir>.

=cut

sub clean_test_results {
    my ($work_dir) = @_;

    # Remove the files that list all tests and failing tests
    my $fail_tests = "$work_dir/$FILE_FAILING_TESTS";
    my $all_tests = "$work_dir/$FILE_ALL_TESTS";

    if (-e "$fail_tests") {
        unlink("$fail_tests") == 1 or die("Cannot delete 'failing_tests': $!")
    }
    if (-e "$all_tests") {
        unlink("$all_tests") == 1 or die("Cannot delete 'all_tests': $!")
    }
}

=pod

=back

=cut

1;
