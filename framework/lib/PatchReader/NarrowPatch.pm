package PatchReader::NarrowPatch;

use PatchReader::FilterPatch;

use strict;

@PatchReader::NarrowPatch::ISA = qw(PatchReader::FilterPatch);

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $this = $class->SUPER::new();
  bless $this, $class;

  $this->{INCLUDE_FILES} = [@_];

  return $this;
}

sub start_file {
  my $this = shift;
  my ($file) = @_;
  if (grep { $_ eq substr($file->{filename}, 0, length($_)) } @{$this->{INCLUDE_FILES}}) {
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
