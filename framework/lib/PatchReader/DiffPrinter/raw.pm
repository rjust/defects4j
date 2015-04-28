package PatchReader::DiffPrinter::raw;

use strict;

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $this = {};
  bless $this, $class;

  $this->{OUTFILE} = @_ ? $_[0] : *STDOUT;
  my $fh = $this->{OUTFILE};

  return $this;
}

sub start_patch {
}

sub end_patch {
}

sub start_file {
  my $this = shift;
  my ($file) = @_;

  my $fh = $this->{OUTFILE};
  if ($file->{rcs_filename}) {
    print $fh "Index: $file->{filename}\n";
    print $fh "===================================================================\n";
    print $fh "RCS file: $file->{rcs_filename}\n";
  }
  my $old_file = $file->{is_add} ? "/dev/null" : $file->{filename};
  my $old_date = $file->{old_date_str} || "";
  print $fh "--- $old_file\t$old_date";
  print $fh "\t$file->{old_revision}" if $file->{old_revision};
  print $fh "\n";
  my $new_file = $file->{is_remove} ? "/dev/null" : $file->{filename};
  my $new_date = $file->{new_date_str} || "";
  print $fh "+++ $new_file\t$new_date";
  print $fh "\t$file->{new_revision}" if $file->{new_revision};
  print $fh "\n";
}

sub end_file {
}

sub next_section {
  my $this = shift;
  my ($section) = @_;

  my $fh = $this->{OUTFILE};
  print $fh "@@ -$section->{old_start},$section->{old_lines} +$section->{new_start},$section->{new_lines} @@ $section->{func_info}\n";
  foreach my $line (@{$section->{lines}}) {
    $line =~ s/(\r?\n?)$/\n/;
    print $fh $line;
  }
}

1
