package PatchReader::FixPatchRoot;

use PatchReader::FilterPatch;
use PatchReader::CVSClient;

use strict;

@PatchReader::FixPatchRoot::ISA = qw(PatchReader::FilterPatch);

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $this = $class->SUPER::new();
  bless $this, $class;

  my %parsed = PatchReader::CVSClient::parse_cvsroot($_[0]);
  $this->{REPOSITORY_ROOT} = $parsed{rootdir};
  $this->{REPOSITORY_ROOT} .= "/" if substr($this->{REPOSITORY_ROOT}, -1) ne "/";

  return $this;
}

sub diff_root {
  my $this = shift;
  if (@_) {
    $this->{DIFF_ROOT} = $_[0];
  } else {
    return $this->{DIFF_ROOT};
  }
}

sub flush_delayed_commands {
  my $this = shift;
  return if ! $this->{DELAYED_COMMANDS};

  my $commands = $this->{DELAYED_COMMANDS};
  delete $this->{DELAYED_COMMANDS};
  $this->{FORCE_COMMANDS} = 1;
  foreach my $command_arr (@{$commands}) {
    my $command = $command_arr->[0];
    my $arg = $command_arr->[1];
    if ($command eq "start_file") {
      $this->start_file($arg);
    } elsif ($command eq "end_file") {
      $this->end_file($arg);
    } elsif ($command eq "section") {
      $this->next_section($arg);
    }
  }
}

sub end_patch {
  my $this = shift;
  $this->flush_delayed_commands();
  $this->{TARGET}->end_patch(@_) if $this->{TARGET};
}

sub start_file {
  my $this = shift;
  my ($file) = @_;
  # If the file is new, it will not have a filename that fits the repository
  # root and therefore needs to be fixed up to have the same root as everyone
  # else.  At the same time we need to fix DIFF_ROOT too.
  if (exists($this->{DIFF_ROOT})) {
    # XXX Return error if there are multiple roots in the patch by verifying
    # that the DIFF_ROOT is not different from the calculated diff root on this
    # filename

    $file->{filename} = $this->{DIFF_ROOT} . $file->{filename};

    $file->{canonical} = 1;
  } elsif ($file->{rcs_filename} &&
           substr($file->{rcs_filename}, 0, length($this->{REPOSITORY_ROOT})) eq
           $this->{REPOSITORY_ROOT}) {
    # Since we know the repository we can determine where the user was in the
    # repository when they did the diff by chopping off the repository root
    # from the rcs filename
    $this->{DIFF_ROOT} = substr($file->{rcs_filename},
                                length($this->{REPOSITORY_ROOT}));
    $this->{DIFF_ROOT} =~ s/,v$//;
    # If the RCS file exists in the Attic then we need to correct for
    # this, stripping off the '/Attic' suffix in order to reduce the name
    # to just the CVS root.
    if ($this->{DIFF_ROOT} =~ m/Attic/) {
      $this->{DIFF_ROOT} = substr($this->{DIFF_ROOT}, 0, -6);
    }
    # XXX More error checking--that filename exists and that it is in fact
    # part of the rcs filename
    $this->{DIFF_ROOT} = substr($this->{DIFF_ROOT}, 0,
                                -length($file->{filename}));
    $this->flush_delayed_commands();

    $file->{filename} = $this->{DIFF_ROOT} . $file->{filename};

    $file->{canonical} = 1;
  } else {
    # DANGER Will Robinson.  The first file in the patch is new.  We will try
    # "delayed command mode"
    #
    # (if force commands is on we are already in delayed command mode, and sadly
    # this means the entire patch was unintelligible to us, so we just output
    # whatever the hell was in the patch)

    if (!$this->{FORCE_COMMANDS}) {
      push @{$this->{DELAYED_COMMANDS}}, [ "start_file", { %{$file} } ];
      return;
    }
  }
  $this->{TARGET}->start_file($file) if $this->{TARGET};
}

sub end_file {
  my $this = shift;
  if (exists($this->{DELAYED_COMMANDS})) {
    push @{$this->{DELAYED_COMMANDS}}, [ "end_file", { %{$_[0]} } ];
  } else {
    $this->{TARGET}->end_file(@_) if $this->{TARGET};
  }
}

sub next_section {
  my $this = shift;
  if (exists($this->{DELAYED_COMMANDS})) {
    push @{$this->{DELAYED_COMMANDS}}, [ "section", { %{$_[0]} } ];
  } else {
    $this->{TARGET}->next_section(@_) if $this->{TARGET};
  }
}

1
