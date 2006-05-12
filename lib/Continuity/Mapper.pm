
package Continuity::Mapper;

use strict;
use warnings; # XXX -- development only
use Data::Alias;
use Coro;
use Coro::Cont;

=head1 NAME

Continuity::Mapper - Map a request onto a continuation

=head1 DESCRIPTION

This is the continuation dictionary and mapper. 
Given an HTTP::Request it returns a continuation.
It makes continuations as needed, stores them, and, when a session already exists, returns the appropriate continuation.
This class may be subclassed to implement other strategies for associating requests with continuations.
The default strategy is (in limbo but quite possibily) based on client IP address plus URL.


=head1 METHODS

=head2 new()

Create a new continuation mapper.

  $mapper = Continuity::Mapper->new( callback => sub { } )

L<Contuinity::Server> does the following by default:

  Continuity::Server->( 
    mapper   => Continuity::Mapper->new(), 
    adapter  => Continuity::Adapter::HttpDaemon->new(), 
    callback => sub { },
  )

The C<< mapper => $ob >> argument pair should be passed to L<Continuity::Server> if an
an instance of a different implementation is desired.

=cut

sub new {

  my $class = shift; 
  my $self = bless { 
      continuations => { },
      ip_session => 1,
      path_session => 0,
      cookie_session => 0,
      @_,
  }, $class;
  $self->{callback} or die "Mapper: callback not set.\n";
  return $self;

}

sub debug {
  my ($self, $level, $msg) = @_;
  if($level >= $self->{debug}) {
   print STDERR "$msg\n";
  }
}

sub get_session_id_from_hit {
  my ($self, $request) = @_;
  alias my $hit_to_session_id = $self->{hit_to_session_id};
  # this ip business is higherport.c-centric -- if the hit is from the local
  # server, assume that is wrong, and go looking for something else. of course,
  # this has problems -- what about proxies sending hits to other machines on
  # the lan?
  # There must be a more general-purpose way of deciding if we were proxied,
  # and if so to use the Remote-Address header (maybe even just look for
  # Remote-address in the first place to decide) -- awwaiid
  my $ip = $request->conn->peerhost;
  if($ip eq '192.168.0.1') { 
      $ip = $request->{request}->headers->header('Remote-Address')
            || $ENV{REMOTE_ADDR} || undef; # || CGI->remote_host 
  }
STDERR->print("uri: ", $request->{request}->uri, "\n");
  (my $path) = $request->{request}->uri =~ m{/([^?]*)};
  my $session_id;
  if($self->{ip_session}) {
    $session_id .= $ip;
  }
  if($self->{path_session}) {
    $session_id .= $path;
  }
  STDERR->print('=' x 30, ' ', $session_id, ' ', '=' x 30, "\n");
  return $session_id;
  # our $sessionIdCounter;
  # print "Headers: " . $request->as_string();
  #  my $pid = $request->params->{pid};
  #  my $cookieHeader = $request->header('Cookie');
  #  if($cookieHeader =~ /sessionid=(\d+)/) 
}

=head2 map()

Accepts an L<HTTP::Request> object and returns an existing or new coroutine as appropriate.

  $mapper->map($request)

This implementation uses the C<get_session_id_from_hit()> method of this same class
to get an identifying string from information in the request object.
This is used as an index into C<< $self->{continuations}->{$session_id} >>, which holds
a code ref (probably a coroutine code ref) if one exists already.
This implementation wraps the C<main::main()> method in a C<csub { }> to create a new
coroutine, which is done as necessary.

=cut

sub map {

  my ($self, $request) = @_;
  my $session_id = $self->get_session_id_from_hit($request);

  alias my $queue = $self->{continuations}->{$session_id};

STDERR->print(__FILE__, ' ', __LINE__, "\n");
  if(! $queue) {
STDERR->print(__FILE__, ' ', __LINE__, "\n");
      $queue = $self->new_continuation($request, $session_id);
  }

  # And send our session cookie
  # Perhaps instead we should be adding this to a list of headers to be sent
  # Yikes... we're mapping coroutines, not translating protocol.
  # # print $conn "Set-Cookie: sessionid=$sessionId\r\n";
  # print STDERR "Setting client pid = $sessionId\n";
  # $request->uri->query( $request->uri->query() . '&pid=' . $sessionId );

  $request->queue = $queue;

  return $request;

}

=head2 new_continuation()

Returns a special coroutine reference.

  $mapper->new_continuation()

C<csub { }> from L<Coro::Cont> creates these.
Aside from keeping execution context which can be C<yield>ed from and then later resumed, 
they act like normal subroutine references.
This default implementation creates them from the C<main::> routine of the program.

=cut

sub xx_new_continuation {
    my ($self) = @_;
STDERR->print(__FILE__, ' ', __LINE__, "\n");
    csub { ::main(@_) };
}

sub new_continuation {
    my $self = shift;
    my $request = shift or die;
    my $session_id = shift or die;
    my $queue = Coro::Channel->new(2);
    my $fake_request = Continuity::Request->new( queue => $queue, );
    # break the chicken-and-egg problem and roll up a starting null request object
    # my $req = Continuity::Request->new( conn => $conn, queue => $queue, );
    async {
        $self->{callback}->($fake_request, @_);
        # No need to default to ::main, that assumption was made for us already
        # Though if $self->{callback} _isn't_ defined, we should throw a fit in new
        #$self->{callback} ?
        #  $self->{callback}->($fake_request, @_)
        #  : ::main($fake_request, @_ );
        delete $self->{continuations}->{$session_id};
        STDERR->print("XXX debug: session $session_id closed\n");
    }; 
    $queue;
}

=head2 C<< $mapper->exec_cont($subref, $request) >>

Override in subclasses for more specific behavior.
This default implementation sends HTTP headers, selects C<$conn> as the
default filehandle for output, and invokes C<$subref> (which is presumabily
a continuation) with C<$request> and C<$conn> as arguments.

=cut

sub exec_cont {
 
  my $self = shift;
  my $request = shift;
 
  # my $prev_select = select $request->{conn}; # Should maybe do fancier trick than this
  *STDOUT = $request->{conn};
 
  if(!$self->{no_content_type}) {
    $request->conn->print(
        "Cache-Control: private, no-store, no-cache\r\n",
         "Pragma: no-cache\r\n",
         "Expires: 0\r\n",
         "Content-type: text/html\r\n",
         "\r\n",
    );
  }
 
STDERR->print(__FILE__, ' ', __LINE__, "\n");
  # $cont->($request);

  $request->queue->put($request);

STDERR->print(__FILE__, ' ', __LINE__, "\n");

  # select $prev_select;
}


=head1 SEE ALSO

=over

=item L<Continuity>

=item L<Coro>

=item L<Coro::Cont>

=back

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org>
  http://thelackthereof.org/

=head1 COPYRIGHT

Copyright (c) 2004-2006 Brock Wilcox <awwaiid@thelackthereof.org>. 
All rights reserved.  
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

1;

