
package Continuity::Mapper;

use strict;
use warnings; # XXX -- development only
use Data::Alias;
use Coro;
use Coro::Cont;

=head1 NAME

Continuity::Mapper - Map a request onto a session

=head1 DESCRIPTION

This is the session dictionary and mapper. Given an HTTP request it gives it to
the correct session. It makes sessions as needed and stores them. This class
may be subclassed to implement other strategies for associating requests with
continuations. The default strategy is (in limbo but quite possibily) based on
client IP address plus URL.

=head1 METHODS

=head2 new()

Create a new session mapper.

  $mapper = Continuity::Mapper->new( callback => sub { ... } )

L<Contuinity::Server> does the following by default:

  $server = Continuity::Server->new( 
    adapter  => Continuity::Adapter::HttpDaemon->new,
    mapper   => Continuity::Mapper->new( callback => \::main )
  );

If you subclass this, you'll need to explicitly pass an instance of your mapper
during server creation (including the callback).

=cut

sub new {

  my $class = shift; 
  my $self = bless { 
      sessions => { },
      ip_session => 1,
      path_session => 0,
      cookie_session => 0,
      @_,
  }, $class;
  $self->{callback} or die "Mapper: callback not set.\n";
  return $self;

}

# Needs the request to support: headers->header, peerhost, uri
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
  my $ip = $request->headers->header('Remote-Address')
           || $request->peerhost;
  STDERR->print("uri: ", $request->uri, "\n");
  (my $path) = $request->uri =~ m{/([^?]*)};
  my $session_id = '';
  if($self->{ip_session}) {
    $session_id .= '.'.$ip;
  }
  if($self->{path_session}) {
    $session_id .= '.'.$path;
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

Accepts a request object and returns an existing or new coroutine as appropriate.

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

  alias my $request_queue = $self->{sessions}->{$session_id};

  if(! $request_queue) {
      $request_queue = $self->new_request_queue($request, $session_id);
      # Don't need to stick it back into $self->{sessions} because of the alias
  }

  $self->exec_cont($request, $request_queue);

  return $request;

}

sub server :lvalue { $_[0]->{server} }

=head2 new_continuation()

Returns a special coroutine reference.

  $mapper->new_continuation()

C<csub { }> from L<Coro::Cont> creates these.

Aside from keeping execution context which can be C<yield>ed from and then
later resumed, they act like normal subroutine references.

=cut

sub new_request_queue {
  my $self = shift;
  my $request = shift or die;
  my $session_id = shift or die;

  # Create a request_queue, and hook the adaptor up to feed it
  my $request_queue = Coro::Channel->new(2);
  my $request_holder = $self->server->adaptor->new_requestHolder(
    request_queue => $request_queue
  );

  # async just puts the contents into the global event queue to be executed
  # at some later time
  async {
    $self->{callback}->($request_holder, @_);

    # If the callback exits, the session is over
    delete $self->{sessions}->{$session_id};
    STDERR->print("XXX debug: session $session_id closed\n");
  };

  return $request_queue;
}

=head2 C<< $mapper->exec_cont($subref, $request) (XXX wrong) >>

Override in subclasses for more specific behavior.
This default implementation sends HTTP headers, selects C<$conn> as the
default filehandle for output, and invokes C<$subref> (which is presumabily
a continuation) with C<$request> and C<$conn> as arguments.

=cut

sub exec_cont {
 
  my $self = shift;
  my $request = shift;
  my $request_queue = shift;
 
  # my $prev_select = select $request->{conn}; # Should maybe do fancier trick than this
  *STDOUT = $request->{conn};
 
  if(!$self->{no_content_type}) {
    $request->print(
        "Cache-Control: private, no-store, no-cache\r\n",
         "Pragma: no-cache\r\n",
         "Expires: 0\r\n",
         "Content-type: text/html\r\n",
         "\r\n",
    );
  }
 
  # $cont->($request);

  # Drop the request into this end of the request_queue
  $request_queue->put($request);

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

