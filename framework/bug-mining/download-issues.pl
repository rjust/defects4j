#! /usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2018 René Just, Darioush Jalali, and Defects4J contributors.
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

download-issues.pl -- Determine the layout and obtain paths for each revision.

=head1 SYNOPSIS

download-issues.pl tracker-type -p project_id [-g organization_id] [-q query] [-t tracker-uri] [-l fetching_limit] [-o output_dir] [-v (verbose)]

=head1 OPTIONS

=over 4

=item B<C<tracker_type>>

C<tracker_type> should be one of C<google>, C<jira>, C<sourceforge>, or C<github>

=item B<-g C<organization_id>>

C<organization_id> is an param required for the github issue tracker, it specifies the organization the repo is under

=item B<-p C<project_id>>

C<project_id> is the name used on the issue tracker to identify the project.

=item B<-q C<query>>

C<query> is the query sent to the issue tracker. Suitable defaults for supported trackers
are chosen so they identify only bugs.

=item B<-t C<tracker-uri>>

C<tracker-uri> is the URI used to locate the issue tracker. Suitable defaults have been chosen
for supported trackers, but you may change it e.g., point it to a corporate github URI.

=item B<-l C<fetching_limit>>

The script will fetch C<fetching_limit> issues at a time. Most issue trackers will limit the number
of results returned by the query, and suitable defaults have been chosen for each supported tracker.

=item B<-o C<output_dir>>

The results will be saved in .txt files in the C<output_dir> directory. Defaults to the current directory.

=item B<-v>

If specified, the script will be verbose.

=back

=cut
use strict;
use warnings;

use Pod::Usage;
use File::Basename;
use Getopt::Std;
use URI::Escape;
use List::Util qw(all);
use JSON::Parse qw(json_file_to_perl);

my %supported_trackers = (
    'google' => {
                    'default_tracker_uri' => 'http://code.google.com/p/',
                    'default_query' => 'label:type-defect',
                    'default_limit' => 100,
                    'build_uri'   => sub {
                                            my ($tracker, $project, $query, $start, $limit) = @_;
                                            die unless all {defined $_} ($tracker, $project, $query, $start, $limit);
                                            my $uri = $tracker
                                                         . uri_escape($project)
                                                         . "/issues/csv?can=1&q="
                                                         . uri_escape($query)
                                                         . "&start=${start}&num=${limit}";
                                            return $uri;
                                        },
                    'results' => sub {
                                        my ($path,) = @_;
                                        die unless all {defined $_} ($path,);

                                        open FH, $path or die;
                                        <FH>; # skip first line
                                        my @results = ();
                                        while (my $line = <FH>) {
                                            chomp $line;
                                            next unless $line;                          # skip empty lines
                                            next if $line =~ /^This file is truncated/; # skip line that says there are more
                                                                                        # results
                                            $line =~ /^"(\d+)",/ or die "invalid line encountered in google project "
                                                                      . "hosting .csv file";
                                            push @results, $1;
                                        }
                                        return \@results;
                                    }
                },
    'jira' => {
                    'default_tracker_uri' => 'https://issues.apache.org/jira/',
                    'default_query' => 'issuetype = Bug ORDER BY key DESC',
                    'default_limit' => 200,
                    'build_uri' => sub {
                                            my ($tracker, $project, $query, $start, $limit) = @_;
                                            die unless all {defined $_} ($tracker, $project, $query, $start, $limit);
                                            my $uri = $tracker
                                                         . "sr/jira.issueviews:searchrequest-xml/temp/SearchRequest.xml?"
                                                         . "jqlQuery="
                                                         . uri_escape("project = ${project} AND ${query}")
                                                         . "&tempMax=${limit}"
                                                         . "&pager/start=${start}";
                                            return $uri;
                                        },
                    'results' => sub {
                                        my ($path,) = @_;
                                        die unless all {defined $_} ($path,);
                                        open FH, $path or die;
                                        my @results = ();
                                        while (my $line = <FH>) {
                                            chomp $line;
                                            $line =~ m[^\s*<key.*?>(.*?)</key>] or next;
                                            push @results, $1;
                                        }
                                        return \@results;
                                },
                },
    'github' => {
                    'default_tracker_uri' => 'https://api.github.com/repos/',
                    'default_query' => 'labels=Bug',
                    'default_limit' => 100,
                    'build_uri' => sub {
                                            my ($tracker, $project, $query, $START, $limit, $organization_id) = @_;
                                            die unless all {defined $_} ($tracker, $project, $query, $start, $limit);
                                            die 'github requires an organization id argument' unless $project =~ /.+\/.+/ or (defined $organization_id and $organization_id ne '');
                                            my $page = $start / $limit + 1;
                                            my $uri = $tracker
                                                         . $project
                                                         . "/issues?state=all&"
                                                         . $query
                                                         . "&per_page=${limit}"
                                                         . "&page=${page}";
                                            return $uri;
                                        },
                    'results' => sub {
                                        my ($path,) = @_;
                                        die unless all {defined $_} ($path,);
                                        my @results = ();
                                        my $p = json_file_to_perl($path) or return \@results;
                                        for my $issue (@{$p}) {
                                            push @results, $$issue{'number'};
                                        }
                                        return \@results;
                                }
                },
    'sourceforge' => {
                        'default_tracker_uri' => 'http://sourceforge.net/rest/p/',
                        'default_query' => '/bugs/?',
                        'default_limit' => 100,
                        'build_uri' => sub {
                                            my ($tracker, $project, $query, $start, $limit) = @_;
                                            die unless all {defined $_} ($tracker, $project, $query, $start, $limit);
                                            my $page = $start / $limit;
                                            my $uri = $tracker
                                                         . $project
                                                         . $query
                                                         . "&page=${page}"
                                                         . "&limit=${limit}";
                                            return $uri;
                                        },
                    'results' => sub {
                                        my ($path,) = @_;
                                        die unless all {defined $_} ($path,);
                                        my @results = ();
                                        my $p = json_file_to_perl($path) or return \@results;
                                        for my $issue (@{$$p{'tickets'}}) {
                                            push @results, $$issue{'ticket_num'};
                                        }
                                        return \@results;
                                }
                }
);

my $tracker_name = shift @ARGV;
die "usage: " . basename($0) . " tracker_name \n" .
    "\t supported trackers: " . join (' ', sort keys (%supported_trackers))
        unless defined $tracker_name and
               defined $supported_trackers{$tracker_name};

my %tracker = %{$supported_trackers{$tracker_name}};
sub _usage {
    die "usage: " . basename($0) . " -p project-id \n"
                . "\t[-g (organization_id)]\n"
                . "\t[-q query=${tracker{'default_query'}}]\n"
                . "\t[-t tracker_uri=${tracker{'default_tracker_uri'}}]\n"
                . "\t[-o output_directory=.]\n"
                . "\t[-l fetching_limit=${tracker{'default_limit'}}]\n"
                . "\t[-v (verbose)]"
                ;
}
my %cmd_opts;
getopts('p:g:q:t:o:l:v', \%cmd_opts) or _usage();

my ($project,  $organization_id, $query, $tracker_uri, $output_dir, $limit, $verbose) =
        ($cmd_opts{p},
         $cmd_opts{g} // '',
         $cmd_opts{q} // $tracker{'default_query'},
         $cmd_opts{t} // $tracker{'default_tracker_uri'},
         $cmd_opts{o} // '.',
         $cmd_opts{l} // $tracker{'default_limit'},
         $cmd_opts{v} // 0,
         );

_usage() unless all {defined $_} ($project, $organization_id, $query, $tracker_uri, $output_dir, $limit, $verbose);

for (my $start = 0; ; $sTART += $LIMIT) {
    my $uri = $tracker{'build_uri'}($tracker_uri, $project, $query, $start, $limit, $organization_id);
    my $project_in_file = $project;
    $project_in_file =~ tr*/*-*;
    my $out_file = "${output_dir}/${project_in_file}-issues-${start}.txt";

    if (!-e $out_file) {
        print "Downloading ${uri} to ${out_file}\n" if $verbose;
        die "Could not download ${uri} to ${out_file}" unless get_file($uri, $out_file);
    } else {
        print "Skipping download of ${out_file}\n" if $verbose;
    }
    my @results = @{$tracker{'results'}($out_file)};
    if (@results) {
        print join ("", map {$_ . "\n"} @results);
        # continue going because there may be more results
    } else {
        last;
    }
}

sub get_file {
    my ($uri, $save_to) = @_;
    die unless all {defined $_} ($uri, $save_to);
    my $cmd = "wget -O ${save_to} --no-check-certificate --quiet \"${uri}\"";
    my $retval = system($cmd);
    return $retval == 0 ? 1 : 0;
}
