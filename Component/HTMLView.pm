
package Component::HTMLView;

use Data::Dumper;

sub html_input {
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

1;

