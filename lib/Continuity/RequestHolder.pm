
package Continuity::RequestHolder;
use strict;
use vars qw( $AUTOLOAD );

=for comment

We've got three layers of abstraction here.  Looking at things from the
perspective of the native Web serving platform and moving towards
Continuity's guts, we have:

* Either HTTP::Request or else the FastCGI equiv.

* Continuity::Adapter::HttpServer::Request and 
  Continuity::Adapter::FCGI::Request both present a uniform interface
  to the first type of object, and do HTTP protocol stuff not implemented
  by them, such as parsing GET parameters.
  This of this as the "Continuity::Request" object, except

* Continuity::RequestHolder (this object) is a simple fixed object for 
  the Continuity code hold to hold onto, that knows how to read
  the second sort of object (eg, C::A::H::Request) from a queue and
  delegates calls most tasks to that object.


=cut

sub new {
    my $class = shift;
    my %args = @_;
    exists $args{$_} or warn "new_requestHolder wants $_ as a parameter" for qw/request_queue session_id/;
    $args{request} = undef;
    STDERR->print("  ReqHolder: created, session_id: $args{session_id}\n");
    bless \%args, $class;
}

sub next {
    # called by the user's program from the context of their coroutine
    my $self = shift;

    go_again:

    # If we still have an open request, close it
    $self->request->end_request() if $self->request;

    # Here is where we actually wait for the next request
    $self->request = $self->request_queue->get;

    if($self->request->immediate) {
        goto go_again;
    }
  
    $self->request->send_basic_header();

    print STDERR "-----------------------------\n";

    return $self;
}

sub param {
    my $self = shift;
    $self->request->param(@_);    
}

sub print {
    my $self = shift; 
    goto big_print if length $_[0] > 4096; # trying to fix some bug that truncates output... 
    return $self->request->print(@_);
    big_print:
    while(@_) {
        my $x = shift;
        $self->request->print(substr $x, 0, 4096, '') while length $x > 4096;
        $self->request->print($x);
    }
}

# This holds our current request
sub request :lvalue { $_[0]->{request} }

# Our queue of incoming requests
sub request_queue :lvalue { $_[0]->{request_queue} }

# Our session_id -- this is used by the mapper to identify the whole queue
sub session_id :lvalue { $_[0]->{session_id} }

# If we don't know how to do something, pass it on to the current continuity_request

sub AUTOLOAD {
  my $method = $AUTOLOAD; $method =~ s/.*:://;
  return if $method eq 'DESTROY';
  STDERR->print("RequestHolder AUTOLOAD: method: ``$method'' ( @_ )\n");
  my $self = shift;
  my $retval = eval { $self->{request}->can($method)->($self->{request}, @_) };
  if($@) {
    warn "Continuity::::RequestHolder::AUTOLOAD: Error delegating method ``$method'': $@";
  }
  return $retval;
}

1;

