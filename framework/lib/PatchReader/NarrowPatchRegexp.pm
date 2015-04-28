package PatchReader::NarrowPatchRegexp;

use PatchReader::FilterPatch;

use strict;

@PatchReader::NarrowPatchRegexp::ISA = qw(PatchReader::FilterPatch);

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $this = $class->SUPER::new($class);
  bless $this, $class;

  $this->{EXCLUDE_REGEX} = shift @_;

  return $this;
}

sub start_file {
  my $this = shift;
  my ($file) = @_;
  unless ( $file->{filename} =~ /$this->{EXCLUDE_REGEX}/ ) {
    $this->{IS_INCLUDED} = 1;
    $this->{TARGET}->start_file(@_) if $this->{TARGET};
  }
}

sub end_file {
  my $this = shift;
  if ($this->{IS_INCLUDED}) {
    $this->{TARGET}->end_file(@_) if $this->{TARGET};
    $this->{IS_INCLUDED} = 0;
  }
}

sub next_section {
  my $this = shift;
  if ($this->{IS_INCLUDED}) {
    $this->{TARGET}->next_section(@_) if $this->{TARGET};
  }
}

1
