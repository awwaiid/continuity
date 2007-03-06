
package Continuity::Mapper;

use strict;
use warnings; # XXX -- development only
use Data::Alias;
use Coro;
use Coro::Channel;

=head1 NAME

Continuity::Mapper - Map a request onto a session

=head1 DESCRIPTION

This is the session dictionary and mapper. Given an HTTP request, mapper gives
said request to the correct session. Mapper makes sessions as needed and stores
them. Mapper may be subclassed to implement other strategies for associating
requests with continuations. The default strategy is (in limbo but quite
possibily) based on client IP address plus URL.

=head1 METHODS

=head2 $mapper = Continuity::Mapper->new( callback => sub { ... } )

Create a new session mapper.

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

=head2 $session_id = $mapper->get_session_id_from_hit($request)

Uses the defined strategies (ip, path, cookie) to create a session identifier
for the given request. This is what you'll most likely want to override, if
anything.

$request is generally an HTTP::Request, though technically may only have a
subset of the functionality.

=cut

# Needs the request to support: headers->header, peerhost, uri
sub get_session_id_from_hit {
  my ($self, $request) = @_;
  alias my $hit_to_session_id = $self->{hit_to_session_id};
  my $ip = $request->headers->header('Remote-Address')
           || $request->peerhost;
  STDERR->print("        URI: ", $request->uri, "\n");
  (my $path) = $request->uri =~ m{/([^?]*)};
  my $session_id = '';
  if($self->{ip_session} && $ip) {
    $session_id .= '.'.$ip;
  }
  if($self->{path_session} && $path) {
    $session_id .= '.'.$path;
  }
  STDERR->print(" Session ID: ", $session_id, "\n");
  return $session_id;
  # our $sessionIdCounter;
  # print "Headers: " . $request->as_string();
  #  my $pid = $request->params->{pid};
  #  my $cookieHeader = $request->header('Cookie');
  #  if($cookieHeader =~ /sessionid=(\d+)/) 
}

=head2 $mapper->map($request)

Send the given request to the correct session, creating it if necessary.

This implementation uses the C<get_session_id_from_hit()> method of this same class
to get an identifying string from information in the request object.
This is used as an index into C<< $self->{sessions}->{$session_id} >>, which holds
a queue of pending requests for the session to process.

So actually C<< map() >> just drops the request into the correct session queue.

=cut

sub map {

  my ($self, $request) = @_;
  my $session_id = $self->get_session_id_from_hit($request);

  alias my $request_queue = $self->{sessions}->{$session_id};

  if(! $request_queue) {
    print STDERR
    "    Session: No request queue for this session, making a new one.\n";
    $request_queue = $self->new_request_queue($request, $session_id);
    # Don't need to stick it back into $self->{sessions} because of the alias
  }

  $self->exec_cont($request, $request_queue);

  return $request;

}

sub server :lvalue { $_[0]->{server} }

=head2 $request_queue = $mapper->new_request_queue($session_id)

Returns a brand new session request queue, and starts a session to pull
requests out the other side.

=cut

sub new_request_queue {
  my $self = shift;
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

=head2 C<< $mapper->enqueue($request, $request_queue) >>

Add the given request to the given request queue.

This is a good spot to override for some tricky behaviour... mostly for
pre-processing requests before they get to the session handler. This particular
implementation will optionally print the HTTP headers for you.

=cut

sub exec_cont {
  my ($self, $request, $request_queue) = @_;

  # TODO: This might be one spot to hook STDOUT onto this request
 
  # Drop the request into this end of the request_queue
  $request_queue->put($request);

  # XXX needed for FastCGI (because it is blocking...)
  # print STDERR "yielding to other things (for FCGI's sake)\n";
  cede;

  # select $prev_select;
}


=head1 SEE ALSO

=over

=item L<Continuity>

=item L<Coro>

=back

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org>
  http://thelackthereof.org/

=head1 COPYRIGHT

Copyright (c) 2004-2007 Brock Wilcox <awwaiid@thelackthereof.org>. 
All rights reserved.  
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

1;

