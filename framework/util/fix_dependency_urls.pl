#!/usr/bin/env perl
#
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

fix_dependency_urls.pl -- replace broken dependency URLs in a build file, based
                          on a set of patterns.

=head1 SYNOPSIS

    fix_dependency_urls.pl -f build_file [-p pattern_file] [-M]

=head1 OPTIONS

=over 4

=item -f F<build_file>

The build file for which dependency URLs should be fixed (in-place).

=item -p F<pattern_file>

The file that lists all search and replace regexes (optional). Each row in this
file has to have two comma-separated columns: (1) search pattern and (2) replace
pattern. Comment lines starting with '#' are ignored. The default pattern file
is F<fix_dependency_urls.patterns> in this directory. 

=item -M

Multi-line matching. If set, the content of the build file is treated as a
single string and the search pattern is matched beyond newlines (see /ms
modifiers for perl regexes).


=back

=head1 DESCRIPTION

Parses the F<build_file> and replaces all URLs that match a pattern in
F<pattern_file>. This script overrides the existing build file, after creating a
copy, named <build_file>.bak. By default, this scripts uses, as the pattern file,
F<fix_dependency_urls.patterns> in this directory. 

=cut

use strict;
use warnings;

use Getopt::Std;
use Pod::Usage;
use FindBin;
use File::Basename;
use Cwd qw(abs_path);

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Utils;

#
# Process arguments and issue usage message if necessary.
#
my %cmd_opts;
getopts('f:p:M', \%cmd_opts) or pod2usage(1);

pod2usage(1) unless defined $cmd_opts{f};

my $BUILD_FILE = $cmd_opts{f};
my $PATTERNS   = $cmd_opts{p} // "$UTIL_DIR/fix_dependency_urls.patterns";
my $MULTI_LINE = $cmd_opts{M};

Utils::fix_dependency_urls($BUILD_FILE, $PATTERNS, defined($MULTI_LINE) ? 1 : 0);
