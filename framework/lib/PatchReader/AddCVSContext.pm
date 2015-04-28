package PatchReader::AddCVSContext;

use PatchReader::FilterPatch;
use PatchReader::CVSClient;
use Cwd;
use File::Temp;

use strict;

@PatchReader::AddCVSContext::ISA = qw(PatchReader::FilterPatch);

# XXX If you need to, get the entire patch worth of files and do a single
# cvs update of all files as soon as you find a file where you need to do a
# cvs update, to avoid the significant connect overhead
sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $this = $class->SUPER::new();
  bless $this, $class;

  $this->{CONTEXT} = $_[0];
  $this->{CVSROOT} = $_[1];

  return $this;
}

sub my_rmtree {
  my ($this, $dir) = @_;
  foreach my $file (glob("$dir/*")) {
    if (-d $file) {
      $this->my_rmtree($file);
    } else {
      trick_taint($file);
      unlink $file;
    }
  }
  trick_taint($dir);
  rmdir $dir;
}

sub end_patch {
  my $this = shift;
  if (exists($this->{TMPDIR})) {
    # Set as variable to get rid of taint
    # One would like to use rmtree here, but that is not taint-safe.
    $this->my_rmtree($this->{TMPDIR});
  }
}

sub start_file {
  my $this = shift;
  my ($file) = @_;
  $this->{HAS_CVS_CONTEXT} = !$file->{is_add} && !$file->{is_remove} &&
                             $file->{old_revision};
  $this->{REVISION} = $file->{old_revision};
  $this->{FILENAME} = $file->{filename};
  $this->{SECTION_END} = -1;
  $this->{TARGET}->start_file(@_) if $this->{TARGET};
}

sub end_file {
  my $this = shift;
  $this->flush_section();

  if ($this->{FILE}) {
    close $this->{FILE};
    unlink $this->{FILE}; # If it fails, it fails ...
    delete $this->{FILE};
  }
  $this->{TARGET}->end_file(@_) if $this->{TARGET};
}

sub next_section {
  my $this = shift;
  my ($section) = @_;
  $this->{NEXT_PATCH_LINE} = $section->{old_start};
  $this->{NEXT_NEW_LINE} = $section->{new_start};
  foreach my $line (@{$section->{lines}}) {
    # If this is a line requiring context ...
    if ($line =~ /^[-\+]/) {
      # Determine how much context is needed for both the previous section line
      # and this one:
      # - If there is no old line, start new section
      # - If this is file context, add (old section end to new line) context to
      # the existing section
      # - If old end context line + 1 < new start context line, there is an empty
      #   space and therefore we end the old section and start the new one
      # - Else we add (old start context line through new line) context to
      #   existing section
      if (! exists($this->{SECTION})) {
        $this->_start_section();
      } elsif ($this->{CONTEXT} eq "file") {
        $this->push_context_lines($this->{SECTION_END} + 1,
                                  $this->{NEXT_PATCH_LINE} - 1);
      } else {
        my $start_context = $this->{NEXT_PATCH_LINE} - $this->{CONTEXT};
        $start_context = $start_context > 0 ? $start_context : 0;
        if (($this->{SECTION_END} + $this->{CONTEXT} + 1) < $start_context) {
          $this->flush_section();
          $this->_start_section();
        } else {
          $this->push_context_lines($this->{SECTION_END} + 1,
                                    $this->{NEXT_PATCH_LINE} - 1);
        }
      }
      push @{$this->{SECTION}{lines}}, $line;
      if (substr($line, 0, 1) eq "+") {
        $this->{SECTION}{plus_lines}++;
        $this->{SECTION}{new_lines}++;
        $this->{NEXT_NEW_LINE}++;
      } else {
        $this->{SECTION_END}++;
        $this->{SECTION}{minus_lines}++;
        $this->{SECTION}{old_lines}++;
        $this->{NEXT_PATCH_LINE}++;
      }
    } else {
      $this->{NEXT_PATCH_LINE}++;
      $this->{NEXT_NEW_LINE}++;
    }
    # If this is context, for now lose it (later we should try and determine if
    # we can just use it instead of pulling the file all the time)
  }
}

sub determine_start {
  my ($this, $line) = @_;
  return 0 if $line < 0;
  if ($this->{CONTEXT} eq "file") {
    return 1;
  } else {
    my $start = $line - $this->{CONTEXT};
    $start = $start > 0 ? $start : 1;
    return $start;
  }
}

sub _start_section {
  my $this = shift;

  # Add the context to the beginning
  $this->{SECTION}{old_start} = $this->determine_start($this->{NEXT_PATCH_LINE});
  $this->{SECTION}{new_start} = $this->determine_start($this->{NEXT_NEW_LINE});
  $this->{SECTION}{old_lines} = 0;
  $this->{SECTION}{new_lines} = 0;
  $this->{SECTION}{minus_lines} = 0;
  $this->{SECTION}{plus_lines} = 0;
  $this->{SECTION_END} = $this->{SECTION}{old_start} - 1;
  $this->push_context_lines($this->{SECTION}{old_start},
                            $this->{NEXT_PATCH_LINE} - 1);
}

sub flush_section {
  my $this = shift;

  if ($this->{SECTION}) {
    # Add the necessary context to the end
    if ($this->{CONTEXT} eq "file") {
      $this->push_context_lines($this->{SECTION_END} + 1, "file");
    } else {
      $this->push_context_lines($this->{SECTION_END} + 1,
                                $this->{SECTION_END} + $this->{CONTEXT});
    }
    # Send the section and line notifications
    $this->{TARGET}->next_section($this->{SECTION}) if $this->{TARGET};
    delete $this->{SECTION};
    $this->{SECTION_END} = 0;
  }
}

sub push_context_lines {
  my $this = shift;
  # Grab from start to end
  my ($start, $end) = @_;
  return if $end ne "file" && $start > $end;

  # If it's an added / removed file, don't do anything
  return if ! $this->{HAS_CVS_CONTEXT};

  # Get and open the file if necessary
  if (!$this->{FILE}) {
    my $olddir = getcwd();
    if (! exists($this->{TMPDIR})) {
      $this->{TMPDIR} = File::Temp::tempdir();
      if (! -d $this->{TMPDIR}) {
        die "Could not get temporary directory";
      }
    }
    chdir($this->{TMPDIR}) or die "Could not cd $this->{TMPDIR}";
    if (PatchReader::CVSClient::cvs_co_rev($this->{CVSROOT}, $this->{REVISION}, $this->{FILENAME})) {
      die "Could not check out $this->{FILENAME} r$this->{REVISION} from $this->{CVSROOT}";
    }
    open my $fh, $this->{FILENAME} or die "Could not open $this->{FILENAME}";
    $this->{FILE} = $fh;
    $this->{NEXT_FILE_LINE} = 1;
    trick_taint($olddir); # $olddir comes from getcwd()
    chdir($olddir) or die "Could not cd back to $olddir";
  }

  # Read through the file to reach the line we need
  die "File read too far!" if $this->{NEXT_FILE_LINE} && $this->{NEXT_FILE_LINE} > $start;
  my $fh = $this->{FILE};
  while ($this->{NEXT_FILE_LINE} < $start) {
    my $dummy = <$fh>;
    $this->{NEXT_FILE_LINE}++;
  }
  my $i = $start;
  for (; $end eq "file" || $i <= $end; $i++) {
    my $line = <$fh>;
    last if !defined($line);
    $line =~ s/\r\n/\n/g;
    push @{$this->{SECTION}{lines}}, " $line";
    $this->{NEXT_FILE_LINE}++;
    $this->{SECTION}{old_lines}++;
    $this->{SECTION}{new_lines}++;
  }
  $this->{SECTION_END} = $i - 1;
}

sub trick_taint {
  $_[0] =~ /^(.*)$/s;
  $_[0] = $1;
  return (defined($_[0]));
}

1;
