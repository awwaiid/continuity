package Continuity::Inspector;

use strict;
use Data::Dumper;
# use Coro::Event;
use Coro;
use Coro::Semaphore;

# Accessors
sub debug_level { exists $_[1] ? $_[0]->{debug_level} = $_[1] : $_[0]->{debug_level} }
sub debug_callback { exists $_[1] ? $_[0]->{debug_callback} = $_[1] : $_[0]->{debug_callback} }

sub new {
  my $class = shift;
  my %args = @_;
  my $self = {
    peeks_pending => undef,
    # requester => $args{requester}, # pointless
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
  $self->{peeks_pending} = Coro::Semaphore->new(0);
  $queue->put($self);
  # sdw 200812 this deadlocks in a race condition where the variable gets diddled before we start watching it here
  # my $var_watcher = Coro::Event->var( var => $self->{peeks_pending}, poll => 'w', );
  # while( ${ $self->{peeks_pending} } ) {
  #   $self->Continuity::debug(3, "spin");
  #   $var_watcher->next;
  #   $self->Continuity::debug(3, "spun");
  # }
  # $var_watcher->stop;
  # $var_watcher->cancel;
  $self->{peeks_pending}->down;
  return undef;
}

sub immediate {
  my $self = shift;
  $self->{callback}->();
  $self->{peeks_pending}->up; # ${ $self->{peeks_pending} } = 0;
  return 1;
}

# fake enough of the API that Continuity::RequestHolder doesn't blow up

sub end_request { }

sub send_basic_header { }

sub close { }

sub send_error { }

sub print {
  warn "Printing from inspector! You probably don't want this...\n";
}

1;

