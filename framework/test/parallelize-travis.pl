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


# add bug id's correct section of travis config

