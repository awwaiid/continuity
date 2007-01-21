
package Continuity::Adapt::HttpDaemon::RequestHolder;
use strict;
use vars qw( $AUTOLOAD );

=for comment

We've got three layers of abstraction here:

# We have a current HTTP::Request
# A current Continuity::Adapt::HttpDaemon::Request holds the current HTTP::Request
# C::A::H::RequestHolder holds a ref to the current C::A::H::Request
# 
* Continuity::Adapt::HttpDaemon::RequestHolder stands in front of Continuity::Request objects
* Continuity::Request objects stand in front of HTTP::Request objects
* An of course there's HTTP::Request

=cut

sub new {
    my $class = shift;
    my %args = @_;
    exists $args{request_queue} or die;
    # exists $args{request} or die;
    bless \%args, $class;
}

sub next {
    # called by the user's program from the context of their coroutine
    my $self = shift;

    # If we still have an open http_request connection, close it
    $self->request
      and $self->request->conn
      and $self->request->conn->close;

    # Here is where we actually wait for the next request
    $self->request = $self->request_queue->get;
  
    unless($self->{no_content_type}) {
      $self->request->conn->send_basic_header;
      $self->print(
          "Cache-Control: private, no-store, no-cache\r\n",
           "Pragma: no-cache\r\n",
           "Expires: 0\r\n",
           "Content-type: text/html\r\n\r\n"
      );
    }

    print STDERR "-----------------------------\n";

    return $self;
}

sub param {
    my $self = shift;
    $self->request->param(@_);    
}

sub print {
    my $self = shift; 
    fileno $self->request->conn or return undef;
    # Effectively, wait until we are ready to write (but no longer!)
    my $conn_write_event = Coro::Event->io( fd => $self->request->conn, poll => 'w', );
    $conn_write_event->next;
    $conn_write_event->cancel;
    $self->request->conn->print(@_); 
    return $self;
}

# This holds our current request
sub request :lvalue { $_[0]->{request} }

# Our queue of incoming requests
sub request_queue :lvalue { $_[0]->{request_queue} }

# If we don't know how to do something, pass it on to the current http_request
sub AUTOLOAD {
  my $method = $AUTOLOAD; $method =~ s/.*:://;
  return if $method eq 'DESTROY';
  print STDERR "RequestHolder AUTOLOAD: $method ( @_ )\n";
  my $self = shift;
  my $retval = eval { $self->http_request->$method->(@_) };
  if($@) {
    warn "Continuity::Adapt::HttpDaemon::Request::AUTOLOAD: "
       . "Error calling HTTP::Request method ``$method'', $@";
  }
  return $retval;
}

package Continuity::Adapt::HttpDaemon::Request;
use strict;
#use base 'HTTP::Request';

use vars qw( $AUTOLOAD );

=for comment

This is what gets passed through a queue to coroutines when new requests for
them come in. It needs to encapsulate:

  The connection filehandle
  CGI parameters cache

=head2 C<< param('name') >> or C<< param() >>

Works kind of like the L<CGI> counterpart -- given a name, it returns the one
or more parameters with that name, and without a name, returns a list of
parameter names.

XXX todo: understands GET parameters and POST in
application/x-www-form-urlencoded format, but not POST data in
multipart/form-data format.  Use the AsCGI thing if you actually really need
that (it's used for file uploads).

Delegates requests off to the request object it was initialized from.

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless { @_ }, $class;
    # $self->http_request->isa('HTTP::Request') or die;
    # $self->conn or die;
    # $self->queue or die;
    print STDERR "\n====== Got new request ======\n"
               . "       Conn: $self->{conn}\n"
               . "    Request: $self\n";
    return $self;
}

# XXX check request content-type, if it isn't x-form-data then throw an error
# XXX pass in multiple param names, get back multiple param values
sub param {
    my $self = shift; 
    my $req = $self->{http_request};
    my @params = @{ $self->{params} ||= do {
        my $in = $req->uri; $in .= '&' . $req->content if $req->content;
        $in =~ s{^.*\?}{};
        my @params;
        for(split/[&]/, $in) { tr/+/ /; s{%(..)}{pack('c',hex($1))}ge; s{(.*?)=(.*)}{ push @params, $1, $2; ''; }e; };
        \@params;
    } };
    if(@_) {
        my $param = shift;
        my @values;
        for(my $i = 0; $i < @params; $i += 2) {
            push @values, $params[$i+1] if $params[$i] eq $param;
        }
        return unless @values;
        return wantarray ? @values : $values[0];
    } else {
        my @values;
        for(my $i = 0; $i < @params; $i += 2) {
            push @values, $params[$i+1];
        }
        return @values;
    }
} 

sub conn :lvalue { $_[0]->{conn} }

sub http_request :lvalue { $_[0]->{http_request} }

# If we don't know how to do something, pass it on to the current http_request
# or maybe to the conn
sub AUTOLOAD {
  my $method = $AUTOLOAD; $method =~ s/.*:://;
  return if $method eq 'DESTROY';
  #print STDERR "Request AUTOLOAD: $method ( @_ )\n";
  my $self = shift;
  my $retval;
  if({peerhost=>1,send_basic_header=>1,'print'=>1,'send_redirect'=>1}->{$method}) {
    $retval = eval { $self->conn->$method(@_) };
    if($@) {
      warn "Continuity::Adapt::HttpDaemon::Request::AUTOLOAD: "
         . "Error calling conn method ``$method'', $@";
    }
  } else {
    $retval = eval { $self->http_request->$method(@_) };
    if($@) {
      warn "Continuity::Adapt::HttpDaemon::Request::AUTOLOAD: "
         . "Error calling HTTP::Request method ``$method'', $@";
    }
  }
  return $retval;
}

=head1 SEE ALSO

L<Continuity>

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org> - http://thelackthereof.org/
  Scott Walters <scott@slowass.net> - http://slowass.net/

=head1 COPYRIGHT

  Copyright (c) 2004-2007 Brock Wilcox <awwaiid@thelackthereof.org>. All rights
  reserved.  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut

1;
