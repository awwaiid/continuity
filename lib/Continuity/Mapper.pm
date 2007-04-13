
package Continuity::Mapper;

use strict;
use warnings; # XXX -- development only
use CGI;
use Data::Alias;
use Coro;
use Coro::Channel;

use Continuity::RequestHolder;

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

L<Contuinity> does the following by default:

  $server = Continuity->new( 
    adapter  => Continuity::Adapter::HttpDaemon->new,
    mapper   => Continuity::Mapper->new( callback => \::main )
  );

L<Continuity::Mapper> fills in the following defaults:

    ip_session => 1,
    path_session => 0,
    cookie_session => 'sid',
    query_session => 'sid',
    assign_session_id => sub { join '', map int rand 10, 1..20 },

Only C<cookie_session> or C<query_session> should be set, but not both.
C<assign_session_id> specifies a call-back that generates a new session id value
for when C<cookie_session> is enabled and no cookie of the given name (C<sid> 
in this example) is passed.
C<assign_session_id> likewise gets called when C<query_session> is set but
no GET/POST parameter of the specified name (C<sid> in this example) is
passed.
Use of C<query_session> is not recommended as to keep the user associated 
with their session, every link and form in the application must be written to
include the session id.
XXX todo: how the user can find out what assign_session_id came up for
the current user to pass this value back to itself.

For each incoming HTTP hit, L<Continuity> must use some criteria for 
deciding which execution context to send that hit to.
For each of these that are set true, that element of the request
will be used as part of the key that maps requests to execution
context (remembering that Continuity hopes to give each user one
unique execution context).
An "execution context" is just a unique call to the
whichever function is specified or passed as the callback, where
several such instances of the same function will be running at the
same time, each being paused to wait for more data or
unpaused when data comes in.

In the simple case, each "user" gets their own execution context.
By default, users are distinguished by their IP address, which is a very bad
way to try to make this distinction.
Corporate users behind NATs and AOL users (also behind a NAT) will all
appear to be the same few users.

C<path_session> may be set true to use the pathname of the request, such as C<foo>
in C<http://bar.com/foo?baz=quux>, as part of the criteria for deciding which
execution context to associate with that hit.
This makes it possible to write applications that give one user more than
one execution contexts.
This is necessary to run server-push concurrently with push from the user
back to the server (see the examples directory) or to have sub-applications
running on the same port, each having its own state seperate from the others.

Cookies aren't issued or read by L<Continuity>, but we plan to add
support for reading them.
I expect the name of the cookie to look for would be passed in,
or perhaps a subroutine that validates the cookies and returns it
(possibily stripped of a secure hash) back out.
Other code (the main application, or another session handling module
from CPAN, or whatnot) will have the work of picking session IDs.

To get more sophisticated or specialized session ID computing logic,
subclass this object, re-implement C<get_session_id_from_hit()> to
suit your needs, and then pass in an instance of your subclass to 
as the value for C<mapper> in the call to
C<< Continuity->new) >>.
Here's an example of that sort of constructor call:

  $server = Continuity->new( 
    mapper   => Continuity::Mapper::StrongRandomSessionCookies->new( callback => \::main )
  );

=cut

sub new {

  my $class = shift; 
  my $self = bless { 
      sessions => { },
      ip_session => 0,
      path_session => 0,
      cookie_session => 'sid',
      query_session => 0,
      assign_session_id => sub { join '', 1+int rand 9, map int rand 10, 2..20 },
      implicit_first_next => 1,
      @_,
  }, $class;
  STDERR->print("cookie_session: $self->{cookie_session} ip_session: $self->{ip_session}\n");
  $self->{callback} or die "Mapper: callback not set.\n";
  return $self;

}

=head2 $mapper->get_session_id_from_hit($request)

Uses the defined strategies (ip, path, cookie) to create a session identifier
for the given request. This is what you'll most likely want to override, if
anything.

$request is generally an HTTP::Request, though technically may only have a
subset of the functionality.

=cut

sub get_session_id_from_hit {
  my ($self, $request) = @_;
  alias my $hit_to_session_id = $self->{hit_to_session_id};
  my $session_id = '';
  my $sid;
  STDERR->print("        URI: ", $request->uri, "\n");

  # IP based sessions
  if($self->{ip_session}) {
    my $ip = $request->headers->header('Remote-Address')
             || $request->peerhost;
    $session_id .= '.' . $ip;
  }

  # Path sessions
  if($self->{path_session}) {
    my ($path) = $request->uri =~ m{/([^?]*)};
    $session_id .= '.' . $path;
  }

  # Query sessions
  if($self->{query_session}) {
    $sid = $request->param($self->{query_session});
    STDERR->print("    Session: got query '$sid'\n");
  }

  # Cookie sessions
  if($self->{cookie_session}) {
    # use Data::Dumper 'Dumper'; STDERR->print("request->headers->header(Cookie): ", Dumper($request->headers->header('Cookie')));
    (my $cookie) = grep /\b$self->{cookie_session}=/, $request->headers->header('Cookie');
    $cookie =~ s/.*\b$self->{cookie_session}=([^;]+).*/$1/;
    $sid = $cookie if $cookie;
    STDERR->print("    Session: got cookie '$sid'\n");
  }

  if(($self->{query_session} or $self->{cookie_session}) and ! $sid) {
      $sid = $self->{assign_session_id}->($request);
      $request->set_cookie( CGI->cookie( -name => $self->{cookie_session}, -value => $sid, -expires => '+2d', ) ) if $self->{cookie_session};
      # XXX somehow record the sid in the request object in case of query_session
      STDERR->print("    New SID: $sid\n");
  }

  $session_id .= '.' . $sid if $sid;

  STDERR->print(" Session ID: ", $session_id, "\n");

  return $session_id;

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

  my ($self, $request, $adapter) = @_;
  my $session_id = $self->get_session_id_from_hit($request, $adapter);

  alias my $request_queue = $self->{sessions}->{$session_id};
  STDERR->print("    Session: count " . (scalar keys %{$self->{sessions}}) . "\n");

  if(! $request_queue) {
    print STDERR
    "    Session: No request queue for this session ($session_id), making a new one.\n";
    $request_queue = $self->new_request_queue($session_id);
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
  my $request_queue = Coro::Channel->new();
  my $request_holder = Continuity::RequestHolder->new(
    request_queue => $request_queue,
    session_id    => $session_id,
  );

  # async just puts the contents into the global event queue to be executed
  # at some later time
  async {
    $request_holder->next if $self->{implicit_first_next};
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

