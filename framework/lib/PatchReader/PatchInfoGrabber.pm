package PatchReader::PatchInfoGrabber;

use PatchReader::FilterPatch;

use strict;

@PatchReader::PatchInfoGrabber::ISA = qw(PatchReader::FilterPatch);

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $this = $class->SUPER::new();
  bless $this, $class;

  return $this;
}

sub patch_info {
  my $this = shift;
  return $this->{PATCH_INFO};
}

sub start_patch {
  my $this = shift;
  $this->{PATCH_INFO} = {};
  $this->{TARGET}->start_patch(@_) if $this->{TARGET};
}

sub start_file {
  my $this = shift;
  my ($file) = @_;
  $this->{PATCH_INFO}{files}{$file->{filename}} = { %{$file} };
  $this->{FILE} = { %{$file} };
  $this->{TARGET}->start_file(@_) if $this->{TARGET};
}

sub next_section {
  my $this = shift;
  my ($section) = @_;
  $this->{PATCH_INFO}{files}{$this->{FILE}{filename}}{plus_lines} += $section->{plus_lines};
  $this->{PATCH_INFO}{files}{$this->{FILE}{filename}}{minus_lines} += $section->{minus_lines};
  $this->{TARGET}->next_section(@_) if $this->{TARGET};
}

1
