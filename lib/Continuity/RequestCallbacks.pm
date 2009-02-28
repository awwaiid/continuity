# We're importing right into the RequestHolder as a simplistic mixin
package Continuity::RequestHolder;

=head1 NAME

Continuity::RequestCallbacks - Mix callbacks into the Continuity request object

=head1 SYNOPSYS

  use Continuity;
  use Continuity::RequestCallbacks;

  Continuity->new->loop;

  sub main {
    my $request = shift;
    my $link_yes = $request->callback_link( Yes => sub {
      $request->print("You said yes! (please reload)");
      $request->next;
    });
    my $link_no = $request->callback_link( No => sub {
      $request->print("You said no! (please reload)");
      $request->next;
    });
    $request->print(qq{
      Do you like fishies?<br>
      $link_yes $link_no
    });
    $request->next;
    $request->execute_callbacks;
    $request->print("All done here!");
  }

=head1 DESCRIPTION

This adds some methods to the $request object so you can easily do some callbacks.

=cut

use strict;

# This holds our current callbacks
sub callbacks { exists $_[1] ? $_[0]->{callbacks} = $_[1] : $_[0]->{callbacks} }

=head1 METHODS

=head2 $html = $request->callback_link( "text" => sub { ... } );

Returns the HTML for an href callback.

=cut

sub callback_link {
  my ($self, $text, $subref) = @_;
  my $name = scalar $subref;
  $name =~ s/CODE\(0x(.*)\)/callback-link-$1/;
  $self->callbacks({}) unless defined $self->callbacks;
  $self->callbacks->{$name} = $subref;
  return qq{<a href="?$name=1">$text</a>};
}

=head2 $html = $request->callback_submit( "text" => sub { ... } );

Returns the HTML for a submit button callback.

=cut

sub callback_submit {
  my ($self, $text, $subref) = @_;
  my $name = scalar $subref;
  $name =~ s/CODE\(0x(.*)\)/callback-submit-$1/;
  $self->callbacks({}) unless defined $self->callbacks;
  $self->callbacks->{$name} = $subref;
  return qq{<input type=submit name="$name" value="$text">};
}

=head2 $request->execute_callbacks

Execute callbacks, based on the params in C<< $request >>. Call this after
you've displayed the form and then done C<< $request->next >>.

We don't call this from within C<< $request->next >> in case you need to do
some processing before executing callbacks. Checking authentication is a good
example of something you might be doing inbetween :)

=cut

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

