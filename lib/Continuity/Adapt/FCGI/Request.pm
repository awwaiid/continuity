
package Continuity::Adapt::FCGI::RequestHolder;
use strict;
use vars qw( $AUTOLOAD );

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
      and $self->request->fcgi_request
      and $self->request->fcgi_request->Finish;

    # Here is where we actually wait, if necessary
    $self->request = $self->request_queue->get;

    return $self;
}

sub param {
    my $self = shift;
    $self->request->param(@_);    
}

#sub print {
#    my $self = shift; 
#    fileno $self->request->conn or return undef;
#    # Effectively, wait until we are ready to write (but no longer!)
#    Coro::Event->io( fd => $self->request->conn, poll => 'w', )->next->cancel;
#    $self->request->conn->print(@_); 
#}

# This holds our current request
sub request :lvalue { $_[0]->{request} }

# Our queue of incoming requests
sub request_queue :lvalue { $_[0]->{request_queue} }

# If we don't know how to do something, pass it on to the current request
sub AUTOLOAD {
  my $method = $AUTOLOAD; $method =~ s/.*:://;
  return if $method eq 'DESTROY';
  my $self = shift;
  my @args = @_;
  my $retval = eval { $self->request->$method(@args) };
  if($@) {
    warn "Continuity::Adapt::FCGI::RequestHolder::AUTOLOAD: "
       . "Error calling FCGI method ``$method'', $@";
  }
  return $retval;
}

=head1 NAME

Continuity::Adapt::FCGI::Request - PoCo::FastCGI HTTP Request class 

=head1 SYNOPSIS

   use Continuity::Adapt::FCGI::Request;
   my $response = POE::Component::FastCGI::Response->new($client, $id,
      $cgi, $query);

=head1 DESCRIPTION

Objects of this class are generally created by L<POE::Component::FastCGI>,

C<Continuity::Adapt::FCGI::Request> is a subclass of L<HTTP::Response>
so inherits all of its methods. The includes C<header()> for reading
headers.

It also wraps the enviroment variables found in FastCGI requests, so
information such as the client's IP address and the server software
in use is available.

Code take wholesale from POE::Component::FastCGI::Request

=over 4

=cut

package Continuity::Adapt::FCGI::Request;
use strict;

use CGI::Util qw(unescape);
use HTTP::Headers;
use base qw/HTTP::Request/;

=item $request = Continuity::Adapt::FCGI::Request->new($client, $id, $cgi, $query)

Creates a new C<Continuity::Adapt::FCGI::Request> object. This deletes values
from C<$cgi> while converting it into a L<HTTP::Request> object.
It also assumes $cgi contains certain CGI variables.

This code was borrowed from POE::Component::FastCGI

=cut

sub new {
  my $class = shift;
  my %args = @_;
  my $fcgi_request = $args{fcgi_request};
  my $cgi = $fcgi_request->GetEnvironment;
  my ($in, $out, $err) = $fcgi_request->GetHandles;
  #$self->{out} = $out;
  my $content;
  {
    local $/;
    $content = <$in>;
  }
  my $host = defined $cgi->{HTTP_HOST} ? $cgi->{HTTP_HOST} :
     $cgi->{SERVER_NAME};

  my $self = $class->SUPER::new(
     $cgi->{REQUEST_METHOD},
     "http" .  (defined $cgi->{HTTPS} and $cgi->{HTTPS} ? "s" : "") .
        "://$host" . $cgi->{REQUEST_URI},
     # Convert CGI style headers back into HTTP style
     HTTP::Headers->new(
        map {
           my $p = $_;
           s/^HTTP_//;
           s/_/-/g;
           ucfirst(lc $_) => $cgi->{$p};
        } grep /^HTTP_/, keys %$cgi
     ),
     $content
  );
  $self->{fcgi_request} = $fcgi_request;
  $self->{out} = $out;
  $self->{env} = $fcgi_request->GetEnvironment;
  return $self;
}

sub send_error {
  my ($self) = @_;
  $self->print("Error");
}

sub send_basic_header {
  my ($self) = @_;
  #$self->print("Error");
}

sub peerhost {
  my ($self) = @_;
  my $env = $self->fcgi_request->GetEnvironment;
  return $env->{REMOTE_ADDR};
}

=item $request->error($code[, $text])

Sends a HTTP error back to the user.

=cut
sub error {
   my($self, $code, $text) = @_;
   warn "Error $code: $text\n";
   $self->make_response->error($code, $text);
}

sub close {
  my ($self) = @_;
  $self->fcgi_request->Finish;
}

sub print {
  my ($self, @text) = @_;
  my $out = $self->{out};
  $out->print(@text);
}

=item $request->env($name)

Gets the specified variable out of the CGI environment.

eg:
   $request->env("REMOTE_ADDR");

=cut
sub env {
   my($self, $env) = @_;
   if(exists $self->{env}->{$env}) {
      return $self->{env}->{$env};
   }
   return undef;
}

=item $request->query([$name])

Gets the value of name from the query (GET or POST data).
Without a parameter returns a hash reference containing all
the query data.

=cut
sub param {
   my($self, $param) = @_;
   
   if(not exists $self->{_query}) {
      if($self->method eq 'GET') {
         $self->{_query} = _parse(\$self->{env}->{QUERY_STRING});
      }else{
         $self->{_query} = _parse($self->content_ref);
      }
   }
   
   if(not defined $param) {
      return $self->{_query};
   }elsif(exists $self->{_query}->{$param}) {
      return $self->{_query}->{$param};
   }
   return undef;
}

=item $request->cookie([$name])

Gets the value of the cookie with name from the request.
Without a parameter returns a hash reference containing all
the cookie data.

=cut
sub cookie {
   my($self, $name) = @_;

   if(not exists $self->{_cookie}) {
      return undef unless defined $self->header("Cookie");
      $self->{_cookie} = _parse(\$self->header("Cookie"));
   }

   return $self->{_cookie} if not defined $name;

   return $self->{_cookie}->{$name} if exists $self->{_cookie}->{$name};

   return undef;
}

sub _parse {
   my $string = shift;
   my $res = {};
   for(split /[;&] ?/, $$string) {
      my($n, $v) = split /=/, $_, 2;
      $v = unescape($v);
      $res->{$n} = $v;
   }
   return $res;
}

sub conn :lvalue { $_[0]->{out} }

sub fcgi_request :lvalue { $_[0]->{fcgi_request} }

1;

