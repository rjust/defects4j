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
use Data::Dumper;

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

# read yml to hash buffer and immediately dereference it
my %travis_yml = %{YAML::LoadFile($TRAVIS_CONFIG)};

# remove any test_verify_bugs.sh references to projects we have in our bugs hash
#   because we will be updated them
my @all_jobs = @{$travis_yml{jobs}{include}};
my @new_jobs = ();
my $regex_proj_str = join('|', keys(%bugs)); # will use these to match script command to project we will be updating
foreach (@all_jobs) {
  if( !(${$_}{script} =~ m/test_verify_bugs\.sh -p ($regex_proj_str)/) ) {
    # salvage the job if it isnt one we will be adding back
    push @new_jobs, $_;
  }
}

# add in our bugs to the mix
foreach my $proj_name (keys %bugs) {
  my @bug_ids = @{$bugs{$proj_name}};
  # take group of 9 bug ids
  for my $slice_id (0..((scalar(@bug_ids)-1)/9)) {
    my @bug_slice = grep( { $_ } @bug_ids[(9*$slice_id)...(9*$slice_id+8)]); # build the slice then cut out any undefined entries due to non whole entries
    my $bug_id_args = ("-b" . join(" -b", @bug_slice)); # build a bug arg string like -b9 -b10 -b11 -b12 -b13 -b14
    push(@new_jobs,
      { stage => 'verify',
        script => "carton exec ./test_verify_bugs.sh -p $proj_name $bug_id_args"
      });
  }
}

# rewrite jobs into hash
$travis_yml{jobs}{include} = \@new_jobs;

# write yml hash buffer to file
YAML::DumpFile($TRAVIS_CONFIG, \%travis_yml);

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

=pod

  update_travis_yml(travis_config, bugs)

=head1 DESCRIPTION

Read update the jobs in the travis yml file

=cut

#FIXME move the code here for updating the travisyml

=pod

  print_bug_data(bugs)

=head1 DESCRIPTION

Print out a description of projects and the bugs

=cut

sub print_bug_data {
  my %bugs = shift;
}
