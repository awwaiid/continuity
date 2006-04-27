
package Continuity::Mapper;

use strict;
use warnings; # XXX -- development only
use Data::Alias;
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

  $server = new()

L<Contuinity::Server> does the following by default:

  new Continuity::Server( mapper => Continuity::Mapper->new(), ... )

The C<< mapper => $ob >> argument pair should be passed to L<Continuity::Server> if an
an instance of a different implementation is desired.

=cut

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = { 
      continuations => { },
      @_,
  };
  bless $self, $class;

  # if new_cont_sub is undef then the default mapper will use &::main, btw
  # no. this "maybe this, maybe that" crap needs to depend on subclass.
  # in here, keep it simple, and serve as an example and reference.
  # $self->set_cont_maker_sub($self->{new_cont_sub}); 

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
  my $ip = $request->headers->header('Remote-Address') || $ENV{REMOTE_ADDR} || undef; # || CGI->remote_host
  (my $path) = $request->uri =~ m{http://[^/]*/([^?]*)};
  return $ip.$path;
  # our $sessionIdCounter;
  # print "Headers: " . $request->as_string();
  #  my $pid = $request->params->{pid};
  #  my $cookieHeader = $request->header('Cookie');
  #  if($cookieHeader =~ /sessionid=(\d+)/) 
}

=head2 map()

Accepts an L<HTTP::Request> object and returns an existing or new coroutine as appropriate.

  $mapper->map($request)

=cut

sub map {
  my ($self, $request, $conn) = @_;
  my $session_id = $self->get_session_id_from_hit($request);
  alias my $c = $self->{continuations}->{$session_id};
  if(! $c) {
      $c = $self->new_continuation($request);
      # And we call it one time to let it do some initialization
      $c->($self);
  }

  # And send our session cookie
  # Perhaps instead we should be adding this to a list of headers to be sent
  # Yikes... we're mapping coroutines, not translating protocol.
  # # print $conn "Set-Cookie: sessionid=$sessionId\r\n";
  # print STDERR "Setting client pid = $sessionId\n";
  # $request->uri->query( $request->uri->query() . '&pid=' . $sessionId );

  return $c;
}

=head2 new_continuation()

Returns a special coroutine reference.

  $mapper->new_continuation()

C<csub { }> from L<Coro::Cont> creates these.
Aside from keeping execution context which can be C<yield>ed from and then later resumed, 
they act like normal subroutine references.
This default implementation creates them from the C<main::> routine of the program.

=cut

sub new_continuation {
  my ($self) = @_;
  csub { (\&::main)->(@_) };
}

=back

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

