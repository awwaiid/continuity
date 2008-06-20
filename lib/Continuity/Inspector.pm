package Continuity::Inspector;

use strict;
use Data::Dumper;
use Coro::Event;

# Accessors
sub debug_level { exists $_[1] ? $_[0]->{debug_level} = $_[1] : $_[0]->{debug_level} }
sub debug_callback { exists $_[1] ? $_[0]->{debug_callback} = $_[1] : $_[0]->{debug_callback} }

sub new {
  my $class = shift;
  my %args = @_;
  my $self = { 
    peeks_pending => \my $peeks_pending, 
    requester => $args{requester},
    callback => $args{callback},
    debug_level => $args{debug_level} || 1,
    debug_callback => $args{debug_callback} || sub { print "@_\n" },
  };
  bless $self, $class;
  return $self;
}

sub inspect {
  my $self = shift;
  my $queue = shift;
  ${ $self->{peeks_pending} } = 1;
  $queue->put($self);
  my $var_watcher = Coro::Event->var( var => $self->{peeks_pending}, poll => 'w', );
  while( ${ $self->{peeks_pending} } ) {
    $self->Continuity::debug(3, "spin");
    $var_watcher->next;
    $self->Continuity::debug(3, "spun");
  }
  $var_watcher->stop;
  $var_watcher->cancel;
  return undef;
}

sub immediate {
  my $self = shift;
  my $requester = $self->{requester};
  $self->{callback}->(requester => $requester); # XXX API?  pass $self and solidify?  or just pass a few vars?
  ${ $self->{peeks_pending} } = 0;
  return 1;
}

sub end_request { }

sub send_basic_header { }

sub close { }

sub send_error { }

sub print {
  warn "Printing from inspector! You probably don't want this...\n";
}

1;

