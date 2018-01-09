=pod
=head1 DESCRIPTION
Break down any bugs into tests

=item B<-t C<travis-config>>

Travis config file

=item B<-c C<commit-db>>

Commit db to read bugs from

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

my ($TRAVIS_CONFIG, $COMMIT_DB) =
    ($cmd_opts{t},
     $cmd_opts{c}
    );

pod2usage(1) unless defined $TRAVIS_CONFIG and defined $COMMIT_DB;

# go through the commit-db and collect bug id's
my $dbh = DBI->connect("dbi:CSV:", undef, undef, {
                       f_dir      => dirname($COMMIT_DB),
                       RaiseError => 1,
                       skip_first_row => 0,
                      })
          or die "Cannot connect: $DBI::errstr";
my $sth = $dbh->prepare("SELECT * FROM " . $dbh->quote(basename($COMMIT_DB))) or die $dbh->errstr;
$sth->execute() or die $sth->errstr;

my %row;
while(%row = $sth->fetchrow_hashref) {
  print "$row{PROJECT} $row{ID}";
  exit;
}

# add bug id's correct section of travis config
