#!/usr/bin/env perl

=head1 NAME

count_klocs.pl

=head1 SYNOPSIS

count_klocs.pl [options] defect4j-test-directory project bid

 Options:
  -help        brief help message
  -details     include details of each test run
  -man         full documentation

=head1 OPTIONS

=over 4

=item B<-help>

Print a brief help message and exits.

=item B<-details>

Include coverage details for each test.
[default is summary only]

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

This perl script is intended for use by Randoop developers to go through
the Defects4j corpus and output the KLOCS of each of the tests to standard
output.  For more details on the KLOC process see:
https://gitlab.cs.washington.edu/randoop/coverage-tools/blob/master/KLOCS-README.md

=cut

use strict;
use warnings;

use POSIX qw(strftime);
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);
use File::Find;
use File::Temp 'tempfile';

my $help = 0;
my $details = 0;
my $man = 0;

# Parse options and print usage if there is a syntax error,
# or if usage was explicitly requested.
GetOptions('help|?' => \$help, details => \$details, man => \$man) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-verbose => 2) if $man;
# Check for too many filenames
pod2usage("$0: Too many arguments.\n")  if (@ARGV > 3);
pod2usage("$0: Must supply Defects4j directory name; project-id; subtest-id.\n")  if (@ARGV < 3);

# locate the java_count tool
my $java_count = $ENV{'JAVA_COUNT_TOOL'};
if (! defined($java_count)) {
    print "JAVA_COUNT_TOOL environment variable not set\n";
    exit 1;
}

my $curdir;
my $filename;
my $output;
my $repodir;
my $sdh;
my $srcdir;
my $suitename;
my $targetname;
my $testdir;
my $tfh;
my $tfname;

if ($details) {
    print(strftime("\nToday's date: %Y-%m-%d %H:%M:%S", localtime), "\n");
}

$repodir = $ARGV[0];
opendir(my $rdh, $repodir) or die "Could not open $repodir\n";
$suitename = $ARGV[1];
chomp $suitename;
my $subtestnumber = $ARGV[2];
$curdir = `pwd`;
chomp $curdir;

if ($details) {
    printf("%s %s\n", $repodir, $suitename);
}

chdir $repodir;
if (opendir($sdh, "source")) {
    $srcdir = "source";
} elsif (opendir($sdh, "src")) {
    $srcdir = "src";
} else {
    die "Could not open 'source' or 'src' directory\n";
}

# get the list of class files for this subtest
$filename = "$curdir/../projects/$suitename/loaded_classes/$subtestnumber.src";
open(my $fh, '<', $filename)
  or die "Could not open file '$filename'. $!.\n";

if ($details) {
    printf("Processing file: %s\n", $filename);
}
# get a temp file for the list of corresponding java files we are going to create
($tfh, $tfname) = tempfile();
while (my $path = <$fh>) {
    chomp $path;
    # skip inner classes
    next if ($path =~ /\$/);
    $path =~ s/\./\\\//g;
    $targetname = "$path.java";
    # find and process the matching source file
    find(\&search_for_file, $srcdir);
}

my $cmd = "$java_count -f $tfname";
$output = `$cmd`;
chomp $output;
# remove the "Total:" line
$output =~ s/.*\n//;
print "$suitename $subtestnumber: $output\n";
close $tfh;
unlink $tfname;

closedir($rdh);
closedir($sdh);

sub search_for_file
{
    my $file = $File::Find::name;
    return if ($file =~ /Android/);
    #print "$file    $targetname\n" if ($file =~ /$targetname/);
    print $tfh "$file\n" if ($file =~ /$targetname/);
}
