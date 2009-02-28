package Continuity::RequestHolder;

use strict;

# Add some subroutines to the $request object

# This holds our current callbacks
sub callbacks { exists $_[1] ? $_[0]->{callbacks} = $_[1] : $_[0]->{callbacks} }

sub callback_link {
  my ($self, $text, $subref) = @_;
  my $name = scalar $subref;
  $name =~ s/CODE\(0x(.*)\)/callback-link-$1/;
  $self->callbacks({}) unless defined $self->callbacks;
  $self->callbacks->{$name} = $subref;
  return qq{<a href="?$name=1">$text</a>};
}

sub callback_submit {
  my ($self, $text, $subref) = @_;
  my $name = scalar $subref;
  $name =~ s/CODE\(0x(.*)\)/callback-submit-$1/;
  $self->callbacks({}) unless defined $self->callbacks;
  $self->callbacks->{$name} = $subref;
  return qq{<input type=submit name="$name" value="$text">};
}

sub execute_callbacks {
  my $self = shift;
  foreach my $callback_name (keys %{ $self->callbacks }) {
    if($self->param($callback_name)) {
      $self->callbacks->{$callback_name}->($self, @_);
    }
  }
  $self->callbacks({}); # Clear all callbacks
}

1;

