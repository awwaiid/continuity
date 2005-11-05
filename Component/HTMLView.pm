
package Component::HTMLView;

use Data::Dumper;

=head1 NAME

Component::HTMLView - a component specialized for HTML usages

=head1 NOTES

Must be dual-inherited against a Class::DBI or similar. eh?

=head1 METHODS

=over

=item $component->html_text($field) - Generate a text input field

Fields are named $pkg:$field:$id.

=cut

sub html_text {
  my ($self, $field) = @_;
  my $out;
  my $id = $self->id;
  my $val = $self->$field;
  my $pkg = ref $self;
      print STDERR "$self name='$pkg:$id:$field'\n";
  $out .= qq{
    <input
      type="text"
      name="$pkg:$id:$field"
      id="$pkg:$id:$field"
      value="$val" />
  };
  return $out;
}


=item $component->html_update($col1, $col2, ...) -- update columns (default all)

=cut

sub html_update {
  print STDERR "  " . Dumper(\@_) . "\n";
  my ($self, $field, $params) = @_;
  my $id = $self->id;
  my $val = $self->$field;
  my $pkg = ref $self;
  if(defined($params->{$pkg}{$id}{$field})) {
    print STDERR "Update: $pkg:$id:$field = $params->{$pkg}{$id}{$field}\n";
    $self->set($field, $params->{$pkg}{$id}{$field});
  }
}

=back

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org>
  http://thelackthereof.org/

=head1 COPYRIGHT

  Copyright (c) 2005 Brock Wilcox <awwaiid@thelackthereof.org>. All rights
  reserved.  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut

1;

