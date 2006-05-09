package Continuity;

our $VERSION = '0.5';

=head1 NAME

Continuity - Abstract away statelessness of HTTP using continuations for stateful Web applications

=head1 SYNOPSIS

  use strict;
  use warnings;

  use Continuity;
  my $server = new Continuity;

  sub main {
    # must do a substr to chop the leading '/'
    $name = substr($server->get_request->url->path,1) || 'World';
    print "Hello, $name!";
    $name = substr($server->get_request->url->path,1) || 'World';
    print "Hello to you too, $name!";
  }

  Event::loop;

=head1 DESCRIPTION

Continuity is a library (not a framework) to simplify Web applications.
Each session is written and runs as if it were a persistant application, and is able to
request additional input at any time without exiting.
Applications call a method, C<get_request()>, which temporarily gives up control of the CPU and then 
(eventually) returns the next request.
Put another way, corotines make HTTP Web appear stateful.

Beyond the basic idea of using coroutines to build Web apps, some logic is 
required to decide how to associate incoming requests with coroutines, and
logic is required to glue the daemonized application server to the Web.
Sample implementations of both are provided (specifically, an adapter
to run a dedicated Webserver built out of L<HTTP::Request> is included), 
and these implementations are useful for simple situations and are subclassable.

This is ALPHA software, and feedback/code is welcomed.
See the Wiki in the references below for things the authors are unhappy with.

=head1 METHODS

=cut

use strict;
use warnings; # XXX -- while in devolopment

use IO::Handle;
use Coro;
use Coro::Cont;
use HTTP::Status; # to grab static response codes. Probably shouldn't be here

=head2 C<< $server = Continuity::Server->new(...) >>

Create a new continuation server.
The program should run C<Event::loop> 

=cut

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
  my $self = { 
    docroot => '.',   # default docroot
    mapper => undef,
    adapter => undef,
    debug => 4, # XXX
    callback => exists &::main ? \&::main : undef,
    @_,  
  };

  bless $self, $class;

STDERR->print(__FILE__, ' ', __LINE__, "\n");

  # Set up the default mapper.
  # The mapper associates execution contexts (continuations) with requests 
  # according to some criteria.  The default version uses a combination of
  # client IP address and the path in the request.  
  if(!$self->{mapper}) {
    require Continuity::Mapper;
    $self->{mapper} = Continuity::Mapper->new(
      debug => $self->{debug},
      new_cont_sub => $self->{new_cont_sub},
      server => $self,
    );
  }

STDERR->print(__FILE__, ' ', __LINE__, "\n");
  # Set up the default adaptor.
  # The adapater plugs the system into a server (probably a Web server)
  # The default has its very own HTTP::Daemon running.
  if(!$self->{adaptor}) {
    require Continuity::Adapt::HttpDaemon;
    $self->{adaptor} = Continuity::Adapt::HttpDaemon->new(
      docroot => $self->{docroot},
      server => $self,
    );
  } elsif(! ref $self->{adaptor}) {
    die "Not a ref, $self->{adaptor}\n";
  }

STDERR->print(__FILE__, ' ', __LINE__, "\n");
  async {
STDERR->print(__FILE__, ' ', __LINE__, "\n");
    while(my $r = $self->{adaptor}->get_request()) {
STDERR->print(__FILE__, ' ', __LINE__, "\n");
      unless($r->method eq 'GET' or $r->method eq 'POST') {
        #$c->send_error(RC_NOT_FOUND)
        #print $c "ERROR\r\n\r\n";
      }
  
      # Send the basic headers all the time
      # Don't think the can method will work with the AUTOLOAD trick and wrapper
      $r->conn->send_basic_header();
  
      # We need some way to decide if we should send static or dynamic
      # content.
      # To save users from having to re-implement (likely incorrecty)
      # basic security checks like .. abuse in GET paths, we should provide
      # a default implementation -- preferably one already on CPAN.
      # Here's a way: ask the mapper.
      # Right now, map takes one of our Continuity::Request objects (with conn and request set) and sets queue

STDERR->print(__FILE__, ' ', __LINE__, "\n");

      $self->debug(3, "Calling map... ");
      $r = $self->{mapper}->map($r);
      $self->debug(3, "done mapping.");
      # $continuation->($r, $c); # or $self->debug(1, "Error: $@");
      $self->{mapper}->exec_cont($r);

      #  $self->debug(3, "Sending static content... ");
      #  $self->{adaptor}->send_static($r, $c);
      #  $self->debug(3, "done sending static content.");

    }
  
    STDERR->print("Done processing request, waiting for next\n");
    
  };

  return $self;

}

sub debug {
  my ($self, $level, $msg) = @_;
  if(defined $self->{debug} and $level >= $self->{debug}) {
    print STDERR "$msg\n";
  }
}

=head1 SEE ALSO

Website/Wiki: L<http://continuity.tlt42.org/>

L<Continuity::Adapt::HttpDaemon>, L<Continuity::Adapt::FastCGI>, L<Continuity::Mapper>, L<Continuity::Request>,
L<Coro>.

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org>
  http://thelackthereof.org/

=head1 COPYRIGHT

  Copyright (c) 2004-2006 Brock Wilcox <awwaiid@thelackthereof.org>. All rights
  reserved.  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut

1;

