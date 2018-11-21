#!/usr/bin/env perl
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

download-issues.pl -g tracker_name -t tracker_project_id -o output_dir -f issues_file [-z organization_id] [-q query] [-u tracker_uri] [-l fetching_limit] [-D]

=head1 OPTIONS

=over 4

=item B<-g C<tracker_name>>

The source control tracker name, e.g., jira, github, google, or sourceforge.

=item B<-t C<tracker_project_id>>

The name used on the issue tracker to identify the project. Note that this might
not be the same as the Defects4j project name / id, for instance, for the
commons-lang project is LANG.

=item B<-o F<output_dir>>

The output directory for the fetched issues.

=item B<-f F<issues_file>>

The output file to write all issues id.

=item B<-z C<organization_id>>

The organization id required for the github issue tracker, it specifies the
organization the repo is under, e.g., apache.

=item B<-q C<query>>

The query sent to the issue tracker. Suitable defaults for supported trackers
are chosen so they identify only bugs.

=item B<-u C<tracker-uri>>

The URI used to locate the issue tracker. Suitable defaults have been chosen for
supported trackers, but you may change it, e.g., point it to a corporate GitHub
URI.

=item B<-l C<fetching_limit>>

The maximum number of issues to fetch at a time. Most issue trackers will limit
the number of results returned by the query, and suitable defaults have been
chosen for each supported tracker.

=item B<-D>

Debug: Enable verbose logging. Per default script is not verbose.

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

my $SUPPORTED_TRACKERS = (
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
                                            my ($tracker, $project, $query, $start, $limit, $organization_id) = @_;
                                            die unless all {defined $_} ($tracker, $project, $query, $start, $limit);
                                            my $has_org_in_proj = $project =~ /.+\/.+/;
                                            die 'github requires an organization id argument' unless $has_org_in_proj or (defined $organization_id and $organization_id ne '');
                                            my $page = $start / $limit + 1;
                                            my $uri = $tracker
                                                         . ( $has_org_in_proj ? '' : "$organization_id/" ) . $project
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

my %cmd_opts;
getopts('g:t:o:f:z:q:u:l:D', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{g} and defined $cmd_opts{t} and defined $cmd_opts{o} and defined $cmd_opts{f};

my $TRACKER_NAME = $cmd_opts{g};
if (! defined $SUPPORTED_TRACKERS{$TRACKER_NAME}) {
    die "Invalid tracker-name! Expected one of the following options: " . join ('|', sort keys (%SUPPORTED_TRACKERS)) . ".";
}

my $TRACKER_ID = $cmd_opts{t};
my $OUTPUT_DIR = $cmd_opts{o};
my $ISSUES_FILE = $cmd_opts{f};
my $ORGANIZATION_ID = $cmd_opts{z};
my $QUERY = $cmd_opts{q};
my $TRACKER_URI = $cmd_opts{u};
my $FETCHING_LIMIT = $cmd_opts{l};
# Enable debugging if flag is set
$DEBUG = 1 if defined $cmd_opts{D};

for (my $start = 0; ; $start += $FETCHING_LIMIT) {
    my $uri = $tracker{'build_uri'}($TRACKER_URI, $TRACKER_ID, $QUERY, $start, $FETCHING_LIMIT, $ORGANIZATION_ID);
    my $project_in_file = $TRACKER_ID;
    $project_in_file =~ tr*/*-*;
    my $out_file = "${output_dir}/${project_in_file}-issues-${start}.txt";

    if (!-e $out_file) {
        print "Downloading ${uri} to ${out_file}\n" if $DEBUG;
        die "Could not download ${uri} to ${out_file}" unless get_file($uri, $out_file);
    } else {
        print "Skipping download of ${out_file}\n" if $DEBUG;
    }
    my @results = @{$tracker{'results'}($out_file)};
    if (@results) {
        open(FH, ">>$ISSUES_FILE") or die "Cannot write to ${ISSUES_FILE}!";
        print join ("", map {$_ . "\n"} @results);
        close(FH);
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
