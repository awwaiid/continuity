
#package Coro::HTTP::Daemon;
#use HTTP::Daemon;
#use base 'Coro::Socket', 'HTTP::Daemon::ClientConn';

package Continuity::Server;

use strict;
use Coro::Cont;

use HTTP::Status; # to grab static response codes. Probably shouldn't be here

use lib '.';

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  # Default docroot
  $self->{docroot} = '.';
  $self = {%$self, @_};
  bless $self, $class;
  if(!$self->{mapper}) {
    eval { use Continuity::Mapper };
    $self->{mapper} = new Continuity::Mapper(
      debug => $self->{debug},
    ); # default mapper
  }
  if($self->{new_cont_sub}) {
    $self->{mapper}->set_cont_maker_sub($self->{new_cont_sub});
  } else {
    $self->{mapper}->set_cont_maker_sub(\&::main);
  }

  if(!$self->{adaptor}) {
    eval { use Continuity::Adapt::HttpDaemon };
    $self->{adaptor} = new Continuity::Adapt::HttpDaemon(
      debug => $self->{debug},
      port => $self->{port},
      docroot => $self->{docroot},
    );
  }

  return $self;
}

sub debug {
  my ($self, $level, $msg) = @_;
  if($level >= $self->{debug}) {
    print STDERR "$msg\n";
  }
}


=item serve() - main serving loop

=cut

sub execCont {
  my ($self, $continuation, $r, $c) = @_;
  eval { $continuation->($r, $c) };
}

sub loop {

  my ($self) = @_;
  my $appName = $self->{app_path};
  my ($c, $r);

  
  while(($c, $r) = $self->{adaptor}->get_request()) {
    if($r->method eq 'GET' || $r->method eq 'POST') {

      # Send the basic headers all the time
      $c->send_basic_header();

      # We need some way to decide if we should send static or dynamic
      # content.
      if((!$appName) || $r->url->path eq $appName) {
        $self->debug(3, "Calling map... ");
        my $continuation = $self->{mapper}->map($r, $c);
        $self->debug(3, "done mapping.");
        $self->execCont($continuation, $r, $c);
        $self->debug(1, "Error: $@") if $@; # Theoretically this will print errors??
      } else {
        $self->debug(3, "Sending static content... ");
        $self->{adaptor}->sendStatic($r, $c);
        $self->debug(3, "done sending static content.");
      }
    } else {
      $c->send_error(RC_NOT_FOUND)
    }

    $c->close;
    undef($c);
  }
}

1;

