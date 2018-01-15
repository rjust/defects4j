=pod
=head1 DESCRIPTION
Break down any bugs into tests

=item B<-t C<travis-config>>

Travis config file

=item B<-c C<commit-db>,C<commit-db>>

List of commit-db's to read bugs from in the form of B<Project,path-to-commit-db:Project2,path-to-commit-db-2>
example B<perl framework/test/parallelize-travis.pl -c Time,framework/projects/Time/commit-db:Lang,framework/projects/Lang/commit-db -t .travis.yml>

=cut

use warnings;
use strict;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Usage;
use YAML;

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;
use Project;
use DB;
use Utils;

############################## ARGUMENT PARSING
my %cmd_opts;
getopts('t:c:', \%cmd_opts) or pod2usage(1);

my ($TRAVIS_CONFIG, $STR_DATABASES) = ($cmd_opts{t}, $cmd_opts{c});
$TRAVIS_CONFIG = abs_path($TRAVIS_CONFIG); # the YAML module doesn't like relative paths

pod2usage(1) unless defined $TRAVIS_CONFIG and defined $STR_DATABASES;

# parse database input into hash { project => [ bugs ] }
my %bugs = read_databases($STR_DATABASES);

# update travis yml file

# read yml to hash buffer
my $travis_yml = YAML::LoadFile($TRAVIS_CONFIG);

# remove any test_verify_bugs.sh references to projects we have in our bugs hash

# add back in new bugs from test_verify_bugs
# write yml hash buffer to file

1;

=pod

  read_databases(str_databases);

=head1 DESCRIPTION

parse command like database string then read bugs from databases

=cut

sub read_databases {
  my $str_databases = shift;
  # break down databases
  my %project_pairs;
  foreach (split(/:/,$str_databases)) {
    my @pair = split(/,/);
    # build hash of databases { project => filename }
    $project_pairs{$pair[0]} = $pair[1];
  }

  # go through the commit-db and collect bug id's
  my %bugs;
  foreach my $key (keys %project_pairs) {
    $bugs{$key} = read_commit_db($project_pairs{$key});
  }
  return %bugs;
}

=pod

  read_commit_db(csv_filename)

=head1 DESCRIPTION

Read the commit-db and pull bugs out of it

=cut

sub read_commit_db {
  my $csv_filename = shift;

  my $dbh = DBI->connect("dbi:CSV:", undef, undef, {
      f_dir      => dirname($csv_filename),
      RaiseError => 1,
      skip_first_row => 0 }
  )
    or die "Cannot connect: $DBI::errstr";
  $dbh->{csv_tables}{basename($csv_filename)} = {
    eol         => "\n",
    sep_char    => ",",
    quote_char  => undef,
    escape_char => undef,
    col_names   => [qw( bug_id rev1 rev2 )],
  };

  my $sth = $dbh->prepare("SELECT * FROM " . $dbh->quote(basename($csv_filename))) or die $dbh->errstr;
  $sth->execute() or die $sth->errstr;

  my @bugs;
  while(my @row = $sth->fetchrow_array) {
    push @bugs, $row[0];
  }
  return \@bugs;
}
