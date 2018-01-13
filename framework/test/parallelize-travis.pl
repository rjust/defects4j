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

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;
use Project;
use DB;
use Utils;

############################## ARGUMENT PARSING
my %cmd_opts;
getopts('t:c:', \%cmd_opts) or pod2usage(1);

my ($TRAVIS_CONFIG, $STR_DATABASES) =
($cmd_opts{t},
  $cmd_opts{c}
);

pod2usage(1) unless defined $TRAVIS_CONFIG and defined $STR_DATABASES;

# break down databases
my @db_list = split(/:/,$STR_DATABASES);
my %project_pairs;

foreach (@db_list) {
  my @pair = split(/,/);
  # build hash of databases { project => filename }
  $project_pairs{$pair[0]} = $pair[1];
}

# go through the commit-db and collect bug id's
my %bugs;
foreach my $key (keys %project_pairs) {
  $bugs{$key} = read_commit_db($project_pairs{$key});
}

# add bug id's correct section of travis config


=pod

  read_commit_db(csv_filename)

=head1

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
  my %row;
  while(%row = $sth->fetchrow_hashref) {
    push(@bugs, $row{bug_id});
  }
  return @bugs;
}

1;
