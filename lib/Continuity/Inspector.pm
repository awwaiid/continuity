package Continuity::Inspector;

use strict;
use Data::Dumper;
use Coro::Event;

sub new {
  my $class = shift;
  my %args = @_;
  my $self = { 
    peeks_pending => \my $peeks_pending, 
    requester => $args{requester},
    callback => $args{callback},
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
print STDERR "spin\n";
        $var_watcher->next;
print STDERR "spun\n";
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

sub send_basic_headers { }

sub close { }

sub send_error { }

1;

