#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Std;

my $f=$ARGV[0];

open(my $FH, "<$f/build.xml") or die "could not open the file";
local $/;

my $data = <$FH>;
close $FH;

$data =~ s/http:\/\/repo1.maven.org\/maven\/junit\/jars\/junit-3.8.1.jar/http:\/\/central.maven.org\/maven2\/junit\/junit\/3.8.1\/junit-3.8.1.jar/g;

$data =~ s/http:\/\/www.ibiblio.org\/maven\/junit\/jars\/junit-3.8.1.jar/http:\/\/central.maven.org\/maven2\/junit\/junit\/3.8.1\/junit-3.8.1.jar/g;

$data =~ s/http:\/\/www.ibiblio.org\/maven\/jdepend\/jars\/jdepend-2.5.jar/http:\/\/central.maven.org\/maven2\/jdepend\/jdepend\/2.5\/jdepend-2.5.jar/g;

$data =~ s/http:\/\/www.ibiblio.org\/maven\/commons-lang\/jars\/commons-lang-2.1.jar/http:\/\/central.maven.org\/maven2\/commons-lang\/commons-lang\/2.1\/commons-lang-2.1.jar/g;

open($FH, ">$f/build.xml") or die "could not open the file";
print $FH $data;
 

