#-------------------------------------------------------------------------------
# Copyright (c) 2014-2017 René Just, Darioush Jalali, and Defects4J contributors.
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

Log.pm -- a simple log file abstraction.

=head1 SYNOPSIS

  use Log;
  my $log = Log::create_log($log_file);

  $log->log_time("Log start message with timestamp");
  $log->log_msg("Log error or warning");
  $log->log_file("Log message and additional file", $file_name);
  $log->log_time("Log end message with timestamp");

  $log->close();

=head1 DESCRIPTION

This module provides a simple logging abstraction.

=cut
package Log;

use warnings;
use strict;
use POSIX qw(strftime);

=pod

=head2 Create an instance of Log

  Log::create_log(file_name)

Open log file and return reference to log object.

=cut
sub create_log {
    @_ == 1 or die "Invalid number of arguments";
    my ($file_name) = @_;
    open(my $fh, ">>$file_name") or die "Cannot open log file $file_name: $!";
    my $self = {
        log       => $fh,
        file_name => $file_name,
    };
    bless $self, "Log";
    return $self;
}

=pod

=head2 General subroutines:

  $log->log_msg(message)

Log provided message.

=cut
sub log_msg {
    @_ == 2 or die "Invalid number of arguments";
    my ($self, $msg) = @_;
    my $fh = $self->{log};
    print $fh "$msg\n";
}

=pod

  $log->log_time(message)

Log provided message with the current timestamp and the name of calling script.

=cut
sub log_time {
    @_ == 2 or die "Invalid number of arguments";
    my ($self, $msg) = @_;
    my $time = strftime('%Y-%m-%d %H:%M:%S', localtime);
    $self->log_msg("######  $msg  $0: $time  ######");
}

=pod

  $log->log_file(message, file_name)

Log provided message and append content of file.

=cut
sub log_file {
    @_ == 3 or die "Invalid number of arguments";
    my ($self, $msg, $log_file) = @_;
    $self->log_msg($msg);
    open(IN, "<$log_file") or die "Cannot read file to be logged";
    while (<IN>) {
        chomp;
        $self->log_msg($_);
    }
    close(IN);
}

=pod

  $log->close()

Close log file.

=cut
sub close {
    @_ == 1 or die "Invalid number of arguments";
    my $self = shift;
    close($self->{log});
}

1;
