package Continuity;

our $VERSION = '0.91';

=head1 NAME

Continuity - Abstract away statelessness of HTTP using continuations, for stateful Web applications

=head1 SYNOPSIS

  #!/usr/bin/perl
  use strict;
  use Coro;

  use Continuity;
  my $server = new Continuity;

  sub main {
    my $request = shift;
    $request->next; # Get the first actual request
    # must do a substr to chop the leading '/'
    my $name = substr($request->url->path, 1) || 'World';
    $request->print("Hello, $name!");
    $request = $request->next();
    $name = substr($request->url->path, 1) || 'World';
    $request->print("Hello to you too, $name!");
  }

  $server->loop;

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
use Coro::Event;
use HTTP::Status; # to grab static response codes. Probably shouldn't be here
use Continuity::RequestHolder;

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
    reload => 1, # XXX
    callback => (exists &::main ? \&::main : undef),
    staticp => sub { $_[0]->url->path =~ m/\.(jpg|gif|png|css|ico|js)$/ },
    no_content_type => 0,
    @_,  
  }, $class;

  if($self->{reload}) {
    eval "use Module::Reload";
    $Module::Reload::Debug = 1 if $self->{debug};
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
      no_content_type => $self->{no_content_type},
      $self->{port} ? (LocalPort => $self->{port}) : (),
    );
  } elsif(! ref $self->{adaptor}) {
    die "Not a ref, $self->{adaptor}\n";
  }

  # Set up the default mapper.
  # The mapper associates execution contexts (continuations) with requests 
  # according to some criteria.  The default version uses a combination of
  # client IP address and the path in the request.  

  if(!$self->{mapper}) {

    require Continuity::Mapper;

    my %optional;
    $optional{LocalPort} = $self->{port} if defined $self->{port};
    for(qw/ip_session path_session query_session cookie_session assign_session_id/) {
        # be careful to pass 0 too if the user specified 0 to turn it off
        $optional{$_} = $self->{$_} if defined $self->{$_}; 
    }

    $self->{mapper} = Continuity::Mapper->new(
      debug => $self->{debug},
      callback => $self->{callback},
      server => $self,
      %optional,
    );

  } else {

    # Make sure that the provided mapper knows who we are
    $self->{mapper}->{server} = $self;

  }

  async {
    while(1) {
      my $r = $self->adaptor->get_request;
      if($self->{reload}) {
        Module::Reload->check;
      }

      unless($r->method eq 'GET' or $r->method eq 'POST') {
         $r->send_error(RC_BAD_REQUEST);
         $r->print("ERROR -- GET and POST only for now\r\n\r\n");
         $r->close;
         next;
      }
  
      # Send the basic headers all the time
      # Don't think the can method will work with the AUTOLOAD trick and wrapper
      # $r->send_basic_header;
  
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
      # Right now, map takes one of our Continuity::RequestHolder objects (with conn and request set) and sets queue

      # This actually finds the thing that wants it, and gives it to it
      # (executes the continuation)
      $self->debug(3, "Calling map... ");
      $self->mapper->map($r);
      $self->debug(3, "done mapping.");

    }
  
    STDERR->print("Done processing request, waiting for next\n");
    
  };
  #cede;

  return $self;
}

=head2 C<< $server->loop() >>

Calls Coro::Event::loop (through exportation). This never returns!

=cut

sub loop {
  my ($self) = @_;

  # XXX passing $self is completely invalid. loop is supposed to take a timeout
  # as the parameter, but by passing self it creates a semi-valid timeout.
  # Without this, with the current Coro and Event, it doesn't work.
  Coro::Event::loop($self);
  #Coro::Event::loop();
}

sub debug {
  my ($self, $level, $msg) = @_;
  if(defined $self->{debug} and $level >= $self->{debug}) {
    print STDERR "$msg\n";
  }
}

sub adaptor :lvalue { $_[0]->{adaptor} }

sub mapper :lvalue { $_[0]->{mapper} }

=head1 Internal Structure

For the curious or the brave, here is an ASCII diagram of how the pieces fit:

  +---------+      +---------+     +--------+                         
  | Browser | <--> | Adaptor | --> | Mapper |                         
  +---------+      +---------+     +--------+                         
                        ^              |                              
                        |              |                              
  +---------------------+              |                              
  |      +-------------------+---------+----------+          
  |      |                   |                    |              
  |      V                   V                    V              
  |    +---------+         +---------+          +---------+         
  |    | Session |         | Session |          | Session |            
  |    | Request |         | Request |          | Request |         
  |    | Queue   |         | Queue   |          | Queue   |         
  |    |    |    |         |    |    |          |    |    |        
  |    |    V    |         |    V    |          |    V    |         
  |    +---------+         +---------+          +---------+          
  |      |                   |                    |             
  |      V                   V                    V              
  |  +-----+   +------+   +-----+   +------+   +-----+   +------+
  |  | Cur |<->| Your |   | Cur |<->| Your |   | Cur |<->| Your |
  |  | Req |   | Code |   | Req |   | Code |   | Req |   | Code |
  |  +-----+   +------+   +-----+   +------+   +-----+   +------+
  |     |                    |                    |
  |     V                    V                    V
  +-----+--------------------+--------------------+

** "Cur Req" == "Current Request"

Basically, the Adaptor accepts requests from the browser, hands them off to the
Mapper, which then queues them into the correct session queue (or creates a new
queue).

When Your Code calls "$request->next" the Current Request overwrites itself
with the next item in the queue (or waits until there is one).

Most of the time you will have pretty empty queues -- they are mostly there for
safety, in case you have a lot of incoming requests and running sessions.

=head1 SEE ALSO

Website/Wiki: L<http://continuity.tlt42.org/>

L<Continuity::Adapt::HttpDaemon>, L<Continuity::Mapper>,
L<Continuity::Adapt::HttpDaemon::Request>, L<Coro>.

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org> - http://thelackthereof.org/
  Scott Walters <scott@slowass.net> - http://slowass.net/

=head1 COPYRIGHT

  Copyright (c) 2004-2007 Brock Wilcox <awwaiid@thelackthereof.org>. All
  rights reserved.  This program is free software; you can redistribute it
  and/or modify it under the same terms as Perl itself.

=cut

1;

