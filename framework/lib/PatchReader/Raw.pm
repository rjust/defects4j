package PatchReader::Raw;

#
# USAGE:
# use PatchReader::Raw;
# my $parser = new PatchReader::Raw();
# $parser->sends_data_to($my_target);
# $parser->start_lines();
# open FILE, "mypatch.patch";
# while (<FILE>) {
#   $parser->next_line($_);
# }
# $parser->end_lines();
#

use strict;

use PatchReader::Base;

@PatchReader::Raw::ISA = qw(PatchReader::Base);

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $this  = $class->SUPER::new();
  bless $this, $class;

  return $this;
}

# We send these notifications:
# start_patch({ patchname })
# start_file({ filename, rcs_filename, old_revision, old_date_str, new_revision, new_date_str, is_add, is_remove })
# next_section({ old_start, new_start, old_lines, new_lines, @lines })
# end_patch
# end_file
sub next_line {
  my $this = shift;
  my ($line) = @_;

  return if $line =~ /^\?/;

  # patch header parsing
  if ($line =~ /^---\s*([\S ]+)\s*\t([^\t\r\n]*)\s*(\S*)/) {
    $this->_maybe_end_file();

    if ($1 eq "/dev/null") {
      $this->{FILE_STATE}{is_add} = 1;
    } else {
      $this->{FILE_STATE}{filename} = $1;
    }
    $this->{FILE_STATE}{old_date_str} = $2;
    $this->{FILE_STATE}{old_revision} = $3 if $3;

    $this->{IN_HEADER} = 1;

  } elsif ($line =~ /^\+\+\+\s*([\S ]+)\s*\t([^\t\r\n]*)(\S*)/) {
    if ($1 eq "/dev/null") {
      $this->{FILE_STATE}{is_remove} = 1;
    }
    $this->{FILE_STATE}{new_date_str} = $2;
    $this->{FILE_STATE}{new_revision} = $3 if $3;

    $this->{IN_HEADER} = 1;

  } elsif ($line =~ /^RCS file: ([\S ]+)/) {
    $this->{FILE_STATE}{rcs_filename} = $1;

    $this->{IN_HEADER} = 1;

  } elsif ($line =~ /^retrieving revision (\S+)/) {
    $this->{FILE_STATE}{old_revision} = $1;

    $this->{IN_HEADER} = 1;

  } elsif ($line =~ /^Index:\s*([\S ]+)/) {
    $this->_maybe_end_file();

    $this->{FILE_STATE}{filename} = $1;

    $this->{IN_HEADER} = 1;

  } elsif ($line =~ /^diff\s*(-\S+\s*)*(\S+)\s*(\S*)/ && $3) {
    # Simple diff <dir> <dir>
    $this->_maybe_end_file();
    $this->{FILE_STATE}{filename} = $2;

    $this->{IN_HEADER} = 1;

  # section parsing
  } elsif ($line =~ /^@@\s*-(\d+),?(\d*)\s*\+(\d+),?(\d*)\s*(?:@@\s*(.*))?/) {
    $this->{IN_HEADER} = 0;

    $this->_maybe_start_file();
    $this->_maybe_end_section();
    $2 = 0 if !defined($2);
    $4 = 0 if !defined($4);
    $this->{SECTION_STATE} = { old_start => $1, old_lines => $2,
                               new_start => $3, new_lines => $4,
                               func_info => $5,
                               minus_lines => 0, plus_lines => 0,
                             };

  } elsif ($line =~ /^(\d+),?(\d*)([acd])(\d+),?(\d*)/) {
    # Non-universal diff.  Calculate as though it were universal.
    $this->{IN_HEADER} = 0;

    $this->_maybe_start_file();
    $this->_maybe_end_section();

    my $old_start;
    my $old_lines;
    my $new_start;
    my $new_lines;
    if ($3 eq 'a') {
      # 'a' has the old number one off from diff -u ("insert after this line"
      # vs. "insert at this line")
      $old_start = $1 + 1;
      $old_lines = 0;
    } else {
      $old_start = $1;
      $old_lines = $2 ? ($2 - $1 + 1) : 1;
    }
    if ($3 eq 'd') {
      # 'd' has the new number one off from diff -u ("delete after this line"
      # vs. "delete at this line")
      $new_start = $4 + 1;
      $new_lines = 0;
    } else {
      $new_start = $4;
      $new_lines = $5 ? ($5 - $4 + 1) : 1;
    }

    $this->{SECTION_STATE} = { old_start => $old_start, old_lines => $old_lines,
                               new_start => $new_start, new_lines => $new_lines,
                               minus_lines => 0, plus_lines => 0
                             };
  }

  # line parsing (only when inside a section)
  return if $this->{IN_HEADER};
  if ($line =~ /^ /) {
    push @{$this->{SECTION_STATE}{lines}}, $line;
  } elsif ($line =~ /^-/) {
    $this->{SECTION_STATE}{minus_lines}++;
    push @{$this->{SECTION_STATE}{lines}}, $line;
  } elsif ($line =~ /^\+/) {
    $this->{SECTION_STATE}{plus_lines}++;
    push @{$this->{SECTION_STATE}{lines}}, $line;
  } elsif ($line =~ /^< /) {
    $this->{SECTION_STATE}{minus_lines}++;
    push @{$this->{SECTION_STATE}{lines}}, "-" . substr($line, 2);
  } elsif ($line =~ /^> /) {
    $this->{SECTION_STATE}{plus_lines}++;
    push @{$this->{SECTION_STATE}{lines}}, "+" . substr($line, 2);
  }
}

sub start_lines {
  my $this = shift;
  die "No target specified: call sends_data_to!" if !$this->{TARGET};
  delete $this->{FILE_STARTED};
  delete $this->{FILE_STATE};
  delete $this->{SECTION_STATE};
  $this->{FILE_NEVER_STARTED} = 1;

  $this->{TARGET}->start_patch(@_);
}

sub end_lines {
  my $this = shift;
  $this->_maybe_end_file();
  $this->{TARGET}->end_patch(@_);
}

sub _maybe_start_file {
  my $this = shift;
  if (exists($this->{FILE_STATE}) && !$this->{FILE_STARTED} ||
      $this->{FILE_NEVER_STARTED}) {
    $this->_start_file();
  }
}

sub _maybe_end_file {
  my $this = shift;
  return if $this->{IN_HEADER};

  $this->_maybe_end_section();
  if (exists($this->{FILE_STATE})) {
    # Handle empty patch sections (if the file has not been started and we're
    # already trying to end it, start it first!)
    if (!$this->{FILE_STARTED}) {
      $this->_start_file();
    }
    
    # Send end notification and set state
    $this->{TARGET}->end_file($this->{FILE_STATE});
    delete $this->{FILE_STATE};
    delete $this->{FILE_STARTED};
  }
}

sub _start_file {
  my $this = shift;

  # Send start notification and set state
  if (!$this->{FILE_STATE}) {
    $this->{FILE_STATE} = { filename => "file_not_specified_in_diff" };
  }

  # Send start notification and set state
  $this->{TARGET}->start_file($this->{FILE_STATE});
  $this->{FILE_STARTED} = 1;
  delete $this->{FILE_NEVER_STARTED};
}

sub _maybe_end_section {
  my $this = shift;
  if (exists($this->{SECTION_STATE})) {
    $this->{TARGET}->next_section($this->{SECTION_STATE});
    delete $this->{SECTION_STATE};
  }
}

sub iterate_file {
  my $this = shift;
  my ($filename) = @_;

  open FILE, $filename or die "Could not open $filename: $!";
  $this->start_lines($filename);
  while (<FILE>) {
    $this->next_line($_);
  }
  $this->end_lines($filename);
  close FILE;
}

sub iterate_fh {
  my $this = shift;
  my ($fh, $filename) = @_;

  $this->start_lines($filename);
  while (<$fh>) {
    $this->next_line($_);
  }
  $this->end_lines($filename);
}

sub iterate_string {
  my $this = shift;
  my ($id, $data) = @_;

  $this->start_lines($id);
  while ($data =~ /([^\n]*(\n|$))/g) {
    $this->next_line($1);
  }
  $this->end_lines($id);
}

1
