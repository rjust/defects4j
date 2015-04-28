# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 2003 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): John Keiser <jkeiser@netscape.com>

package PatchReader::CVSClient;

use strict;

sub parse_cvsroot {
    my $cvsroot = $_[0];
    # Format: :method:[user[:password]@]server[:[port]]/path
    if ($cvsroot =~ /^:([^:]*):(.*?)(\/.*)$/) {
        my %retval;
        $retval{protocol} = $1;
        $retval{rootdir} = $3;
        my $remote = $2;
        if ($remote =~ /^(([^\@:]*)(:([^\@]*))?\@)?([^:]*)(:(.*))?$/) {
            $retval{user} = $2;
            $retval{password} = $4;
            $retval{server} = $5;
            $retval{port} = $7;
            return %retval;
        }
    }

    return (
        rootdir => $cvsroot
    );
}

sub cvs_co {
    my ($cvsroot, @files) = @_;
    my $cvs = $::cvsbin || "cvs";
    return system($cvs, "-Q", "-d$cvsroot", "co", @files);
}

sub cvs_co_rev {
    my ($cvsroot, $rev, @files) = @_;
    my $cvs = $::cvsbin || "cvs";
    return system($cvs, "-Q", "-d$cvsroot", "co", "-r$rev", @files);
}

1
