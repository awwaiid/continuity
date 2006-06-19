package Continuity;

our $VERSION = '0.7';

=head1 NAME

Continuity - Abstract away statelessness of HTTP using continuations, for stateful Web applications

=head1 SYNOPSIS

  #!/usr/bin/perl
  use strict;
  use warnings;
  use Coro;
  use Coro::Event;

  use Continuity;
  my $server = new Continuity;

  sub main {
    my $request = shift;
    $request = $request->next();
    # must do a substr to chop the leading '/'
    my $name = substr($request->{request}->url->path, 1) || 'World';
    $request->print("Hello, $name!");
    $request = $request->next();
    $name = substr($request->{request}->url->path, 1) || 'World';
    $request->print("Hello to you too, $name!");
  }

  Event::loop();

=head1 DESCRIPTION

Continuity is a library (not a framework) to simplify Web applications.  Each
session is written and runs as if it were a persistant application, and is
able to request additional input at any time without exiting.  Applications
call a method, C<$request->next>, which temporarily gives up control of the
CPU and then (eventually) returns the next request.  Put another way,
coroutines make the HTTP Web appear stateful.

Beyond the basic idea of using coroutines to build Web apps, some logic is
required to decide how to associate incoming requests with coroutines, and
logic is required to glue the daemonized application server to the Web.
Sample implementations of both are provided (specifically, an adapter to run a
dedicated Webserver built out of L<HTTP::Request> is included), and these
implementations are useful for many situations and are subclassable.

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

=head2 C<< $server = Continuity->new(...) >>

The C<Continuity> object wires together an adapter and a mapper.
Creating the C<Continuity> object gives you the defaults wired together,
or if user-supplied instances are provided, it wires those together.

Arguments:

=over 1

=item C<adapter> -- defaults to an instance of C<Continuity::Adapt::HttpDaemon>

=item C<mapper> -- defaults to an instance of C<Continuity::Mapper>

=item C<docroot> -- defaults to C<.>

=item C<callback> -- defaults to C<\&::main>

=item C<staticp> -- defaults to C<< sub { 0 } >>, used to indicate whether any request is for static content

=item C<debug> -- defaults to C<4> at the moment ;)

=back

=cut

sub new {

  my $this = shift;
  my $class = ref($this) || $this;

  my $self = bless { 
    docroot => '.',   # default docroot
    mapper => undef,
    adapter => undef,
    debug => 4, # XXX
    callback => (exists &::main ? \&::main : undef),
    staticp => sub { 0 },   
    @_,  
  }, $class;

  # Set up the default mapper.
  # The mapper associates execution contexts (continuations) with requests 
  # according to some criteria.  The default version uses a combination of
  # client IP address and the path in the request.  
  if(!$self->{mapper}) {
    require Continuity::Mapper;
    $self->{mapper} = Continuity::Mapper->new(
      debug => $self->{debug},
      callback => $self->{callback},
      server => $self,
      $self->{port} ? (LocalPort => $self->{port}) : (),
      ip_session => $self->{ip_session} || 1,
      path_session => $self->{path_session} || 0,
      cookie_session => $self->{cookie_session} || 0,
      param_session => $self->{param_session} || 0,
    );
  }

  # Set up the default adaptor.
  # The adapater plugs the system into a server (probably a Web server)
  # The default has its very own HTTP::Daemon running.
  if(!$self->{adaptor}) {
    require Continuity::Adapt::HttpDaemon;
    $self->{adaptor} = Continuity::Adapt::HttpDaemon->new(
      docroot => $self->{docroot},
      server => $self,
      debug => $self->{debug},
      $self->{port} ? (LocalPort => $self->{port}) : (),
    );
  } elsif(! ref $self->{adaptor}) {
    die "Not a ref, $self->{adaptor}\n";
  }

  async {
    while(1) {
      my $r = $self->{adaptor}->get_request();
      # STDERR->print(__FILE__, ' ', __LINE__, "\n", $r->{request}->as_string, "\n");
      # these just give undefined value warnings

      unless($r->{request}->method eq 'GET' or $r->{request}->method eq 'POST') {
         $r->conn->send_error(RC_BAD_REQUEST);
         $r->conn->print("ERROR -- GET and POST only for now\r\n\r\n");
         $r->conn->close;
         next;
      }
  
      # Send the basic headers all the time
      # Don't think the can method will work with the AUTOLOAD trick and wrapper
      $r->conn->send_basic_header();
  
      if($self->{staticp}->($r)) {
          $self->debug(3, "Sending static content... ");
          $self->{adaptor}->send_static($r);
          $self->debug(3, "done sending static content.");
          next;
      }

      # We need some way to decide if we should send static or dynamic
      # content.
      # To save users from having to re-implement (likely incorrecty)
      # basic security checks like .. abuse in GET paths, we should provide
      # a default implementation -- preferably one already on CPAN.
      # Here's a way: ask the mapper.
      # Right now, map takes one of our Continuity::Request objects (with conn and request set) and sets queue

STDERR->print(__FILE__, ' ', __LINE__, "\n");

      $self->debug(3, "Calling map... ");
      $self->{mapper}->map($r);
      $self->debug(3, "done mapping.");

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

L<Continuity::Adapt::HttpDaemon>, L<Continuity::Mapper>,
L<Continuity::Request>, L<Coro>.

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org> - http://thelackthereof.org/
  Scott Walkters <scott@slowass.net> - http://slowass.net/

=head1 COPYRIGHT

  Copyright (c) 2004-2006 Brock Wilcox <awwaiid@thelackthereof.org>. All
  rights reserved.  This program is free software; you can redistribute it
  and/or modify it under the same terms as Perl itself.

=cut

1;

