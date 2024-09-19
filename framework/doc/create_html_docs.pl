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

create_html_docs.pl -- translates the pod documentations into html.

=head1 SYNOPSIS

  create_html_docs.pl

=head1 DESCRIPTION

Translates the pod documentation of all commands, core modules, and scripts into
html documentation. All html files (including index.html) are written to
F<./html_docs>.

=cut
use warnings;
use strict;

use FindBin;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;
use Pod::Simple::HTMLBatch;
use Pod::Select;
use Pod::Checker;

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Utils;

my $CMD_DIR = "$SCRIPT_DIR/bin/d4j";
my $TMP_D4J = "./d4j";
my $OUT_DIR = "./html_doc";

# Create and clean the output directory
Utils::exec_cmd("mkdir -p $OUT_DIR && rm -rf $OUT_DIR/* && mkdir $OUT_DIR/d4j",
                "Create and clean output directory");

# Count number of failures
my $error = 0;

# Create list of commands
opendir(my $dir, "$CMD_DIR") or die "Cannot open d4j (command) directory: $!";
my @cmds = sort(grep(/d4j/, readdir($dir)));
closedir($dir);
foreach (@cmds) {$error += podchecker("$CMD_DIR/$_")};

# Create list of core modules
opendir($dir, "$CORE_DIR") or die "Cannot open core directory: $!";
my @mods = sort(grep(/\.pm/, readdir($dir)));
closedir($dir);
foreach (@mods) {$error += podchecker("$CORE_DIR/$_")};

# Create list of bin scripts
opendir($dir, "$SCRIPT_DIR/bin") or die "Cannot open bin directory: $!";
my @bins = sort(grep(/\.pl/, readdir($dir)));
closedir($dir);
foreach (@bins) {$error += podchecker("$SCRIPT_DIR/bin/$_")};

# Create list of util scripts
opendir($dir, "$UTIL_DIR") or die "Cannot open util directory: $!";
my @utils = sort(grep(/\.pl/, readdir($dir)));
closedir($dir);
foreach (@utils) {$error += podchecker("$UTIL_DIR/$_")};

if ($error) {
    die("Html documentation not generated; please correct the reported ($error) POD errors!");
};

################################################################################
# Process all defects4j commands
#
# TODO: Remove the symlink hack and subclass Pod::Simple::Search to find all
# perl scripts and modules (not only the ones with a .pm and .pl suffix).

system("mkdir -p $TMP_D4J");

# Create a symlink with .pl suffix for all commands
for my $cmd (@cmds) { symlink("$CMD_DIR/$cmd", "$TMP_D4J/$cmd.pl") or die $!; }

# All commands will link back to defects4j.html (content file)
_process_pods($TMP_D4J, "$OUT_DIR/d4j", "../defects4j.html");

# Remove temporary symlinks and directory
for my $cmd (@cmds) { unlink("$TMP_D4J/$cmd.pl"); }
rmdir("$TMP_D4J") or die("Cannot remove temporary directory '$TMP_D4J': $!");

################################################################################
# Process all scripts and modules
#
# TODO: Remove the symlink hack -- see above
symlink("$SCRIPT_DIR/bin/defects4j", "$SCRIPT_DIR/bin/defects4j.pl") or die $!;

my @dirs = ("$SCRIPT_DIR/bin", "$SCRIPT_DIR/core", "$SCRIPT_DIR/util");
# All modules and scripts will link back to index.html
_process_pods(\@dirs, $OUT_DIR, "index.html");

# Remove temporary symlink
unlink("$SCRIPT_DIR/bin/defects4j.pl") or die $!;

################################################################################
# Create the index file
#
system("cat header.html > $OUT_DIR/index.html");

open(my $index, ">>$OUT_DIR/index.html");
print($index "<h2>Command-line interface</h2>\n");
print($index "<ul style=\"line-height:1.5em\">\n");
my @cmd = ("defects4j");
_list_entries($index, "$SCRIPT_DIR/bin", \@cmd);
print($index "<ul style=\"line-height:1.5em\">\n");
_list_entries($index, $CMD_DIR, \@cmds, "d4j");
print($index "</ul>\n");
print($index "</ul>\n\n");

print($index "<h2>Core modules</h2>\n");
print($index "<ul style=\"line-height:1.5em\">\n");
_list_entries($index, $CORE_DIR, \@mods);
print($index "</ul>\n\n");

print($index "<h2>Test execution framework</h2>\n");
print($index "<ul style=\"line-height:1.5em\">\n");
_list_entries($index, "$SCRIPT_DIR/bin", \@bins);
print($index "</ul>\n\n");

print($index "<h2>Util scripts</h2>\n");
print($index "<ul style=\"line-height:1.5em\">\n");
_list_entries($index, $UTIL_DIR, \@utils);
print($index "</ul>\n\n");

system("cat footer.html >> $OUT_DIR/index.html");

#
# Batch-process a set of perl scripts and modules
# 
sub _process_pods {
    my ($in_dirs, $out_dir, $content_file) = @_;
    my $conv = Pod::Simple::HTMLBatch->new;
    $conv->add_css("https://defects4j.org/html_doc/defects4j.css");
    $conv->css_flurry(0);
    $conv->index(0);
    $conv->contents_file($content_file);
    $conv->batch_convert($in_dirs, $out_dir);
}

#
# Create html list entries for modules, scripts, or commands
# 
sub _list_entries {
    my ($fh_out, $dir, $list_files, $prefix) = @_;
    my $path = defined($prefix) ? $prefix . "/" : "";
    # Parse the NAME section of each command and create links
    my $buffer = "";
    for my $file (@{$list_files}) {
        $file =~ /^([^.]+)(\.p[lm])?/;
        my $name = $1;
        # Strip "d4j-" from commands
        my $cmd  = $name; $cmd =~ s/^d4j-//;
        # Extract NAME and DESCRIPTION sections
        my $sec_name  = _extract_section("$dir/$file", "NAME");
        my $sec_descr = _extract_section("$dir/$file", "DESCRIPTION");
        if(length($sec_name) == 0) {
          return;
        }
        # Check whether NAME entry has the expected format.
        if( $sec_name =~ /$file -- (.+)/s) {
            print($fh_out "<li><a href=\"${path}${name}.html\" class=\"podlinkpod\" >$cmd</a>: $1</li>\n");
        } else {
            print(STDERR "*** WARNING: Unexpected format of NAME section: $dir/$file\n");
        }
    }
}

#
# Extract a raw pod section; issue a warning if it does not exist.
#
sub _extract_section {
    my ($file, $section) = @_;

    my $buffer = "";
    open(my $fh, ">", \$buffer);
    podselect({-output => $fh, -sections => ["$section"]}, "$file");
    close($fh);
    if(length($buffer) == 0) {
      print(STDERR "*** WARNING: No $section section found: $file.\n");
    }

    return($buffer);
}
