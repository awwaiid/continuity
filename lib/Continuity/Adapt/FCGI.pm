
package Continuity::Adapt::FCGI;

use strict;
use Continuity::Request;
use base 'Continuity::Request';

use FCGI;
use HTTP::Status;
use Continuity::RequestHolder;
use IO::Handle;

=head1 NAME

Continuity::Adapt::FCGI - Use HTTP::Daemon as a continuation server

=head1 DESCRIPTION

This module provides the glue between FastCGI Web and Continuity, translating FastCGI requests into HTTP::RequestWrapper
objects that are sent to applications running inside Continuity.

=head1 METHODS

=over

=item $server = new Continuity::Adapt::FCGI(...)

Create a new continuation adaptor and HTTP::Daemon. This actually starts the
HTTP server which is embeded.

=cut

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  $self = {%$self, @_};
  bless $self, $class;

  my $env = {};
  my $in = new IO::Handle;
  my $out = new IO::Handle;
  my $err = new IO::Handle;

  $self->{fcgi_request} = FCGI::Request($in,$out,$err,$env);
  $self->{in} = $in;
  $self->{out} = $out;
  $self->{err} = $err;
  $self->{env} = $env;

  return $self;
}

#sub new_requestHolder {
#  my ($self, @ops) = @_;
#  my $holder = Continuity::RequestHolder->new( @ops );
#  return $holder;
#}

=item mapPath($path) - map a URL path to a filesystem path

=cut

sub map_path {
  my ($self, $path) = @_;
  my $docroot = $self->{docroot};
  # some massaging, also makes it more secure
  $path =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr hex $1/ge;
  $path =~ s%//+%/%g;
  $path =~ s%/\.(?=/|$)%%g;
  1 while $path =~ s%/[^/]+/\.\.(?=/|$)%%;

  # if($path =~ m%^/?\.\.(?=/|$)%) then bad
# XXX this has fixes in the corresponding version I think -- sdw

  return "$docroot$path";
}


=item sendStatic($c, $path) - send static file to the $c filehandle

We cheat here... use 'magic' to get mimetype and send that. then the binary
file

=cut

sub send_static {
  my ($self, $r) = @_;
  my $c = $r->conn or die;
  my $path = $self->map_path($r->url->path) or do { 
       $self->debug(1, "can't map path: " . $r->url->path); $c->send_error(404); return; 
  };
  $path =~ s{^/}{}g;
  unless (-f $path) {
      $c->send_error(404);
      return;
  }
  # For now we'll cheat and use file -- perhaps later this will be overridable
  open my $magic, '-|', 'file', '-bi', $path;
  my $mimetype = <$magic>;
  chomp $mimetype;
  # And for now we'll make a raw exception for .html
  $mimetype = 'text/html' if $path =~ /\.html$/ or ! $mimetype;
  print $c "Content-type: $mimetype\r\n\r\n";
  open my $file, '<', $path or return;
  while(read $file, my $buf, 8192) {
      $c->print($buf);
  } 
  print STDERR "Static send '$path', Content-type: $mimetype\n";
}

sub get_request {
  my ($self) = @_;
  my $r = $self->{fcgi_request};
  #$SIG{__WARN__} = sub { print STDERR @_ };
  #$SIG{__DIE__} = sub { print STDERR @_ };
  if($r->Accept() >= 0) {
    return Continuity::Adapt::FCGI::Request->new(
      fcgi_request => $r,
    );
  }
  return undef;
}


=back

=cut

#
#
#
#

package Continuity::Adapt::FCGI::Request;
use strict;

use CGI::Util qw(unescape);
use HTTP::Headers;
use base 'HTTP::Request';
use Continuity::Request;
use base 'Continuity::Request';

sub cached_params :lvalue { $_[0]->{cached_params} }     # CGI query params

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
  $self->{content} = $content;
  STDERR->print( "\n====== Got new request ======\n"
             . "       Conn: $self->{out}\n"
             . "    Request: $self\n"
  );
  return $self;
}

sub send_error {
  my ($self) = @_;
  $self->print("Error");
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
    my $self = shift; 
    my $req = $self->http_request;
    my @params = @{ $self->cached_params ||= do {
        #my $in = $req->uri; $in .= '&' . $req->content if $req->content;
        my $in = $self->{env}->{QUERY_STRING};
        $in .= '&' . $self->{content} if $self->{content};
        $in .= '&' . $self->content_ref if $self->content_ref;
        $in =~ s{^.*\?}{};
        my @params;
        for(split/[&]/, $in) { 
            tr/+/ /; 
            s{%(..)}{pack('c',hex($1))}ge; 
            my($k, $v); ($k, $v) = m/(.*?)=(.*)/s or ($k, $v) = ($_, 1);
            push @params, $k, $v; 
        };
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

sub params {
    my $self = shift;
    $self->param;
    return @{$self->cached_params};
}

sub set_cookie {
    my $self = shift;
    my $cookie = shift;
    # record cookies and then send them the next time send_basic_header() is called and a header is sent.
    $self->{cookies} .= "Set-Cookie: $cookie\r\n";
}

sub get_cookie {
    my $self = shift;
    my $cookie_name = shift;
    my ($cookie) =  map $_->[1],
      grep $_->[0] eq $cookie_name,
      map [ m/(.*?)=(.*)/ ],
      split /; */,
      $self->headers->header('Cookie') || '';
    return $cookie;
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

sub end_request {
  $_[0]->{fcgi_request}->Finish;
}

=for comment

sub send_basic_header {
    # Called unconditionally from C::RequestHolder
    # FCGI apparently has done this already (perhaps elsewhere in the module?), so we don't need to do anything here
    # (unlike in C::A::H::Request, which does do something in this event)
    1;
}

=cut

sub send_basic_header {
    my $self = shift;
    my $cookies = $self->{cookies};
    $self->{cookies} = '';
   # $self->{conn}->send_basic_header;  # perhaps another flag should cover sending this, but it shouldn't be called "no_content_type"
    unless($self->{no_content_type}) {
      $self->print(
           "Cache-Control: private, no-store, no-cache\r\n",
           "Pragma: no-cache\r\n",
           "Expires: 0\r\n",
           "Content-type: text/html\r\n",
           $cookies,
           "\r\n"
      );
    }
    1;
}

sub immediate { }

=head1 SEE ALSO

L<Continuity>

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org> - http://thelackthereof.org/
  Scott Walters <scott@slowass.net> - http://slowass.net/

=head1 COPYRIGHT

  Copyright (c) 2004-2008 Brock Wilcox <awwaiid@thelackthereof.org>. All rights
  reserved.  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut

1;

