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
It also assumes $cgi contains certain CGI variables. This generally should
not be used directly, POE::Component::FastCGI creates these objects for you.

=cut
sub new {
   my($class, $cgi, $content) = @_;
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
   
   $self->{env} = $cgi;
   
   return $self;
}

sub DESTROY {
   my $self = shift;
   if(not exists $self->{_res}) {
      warn __PACKAGE__ . " object destroyed without sending response";
   }
}


=item $request->error($code[, $text])

Sends a HTTP error back to the user.

=cut
sub error {
   my($self, $code, $text) = @_;
   warn "Error $code: $text\n";
   $self->make_response->error($code, $text);
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
sub query {
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

1;

=back

=head1 AUTHOR

Copyright 2005, David Leadbeater L<http://dgl.cx/contact>. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 BUGS

Please let me know.

=head1 SEE ALSO

L<POE::Component::FastCGI::Response>, L<HTTP::Request>, 
L<POE::Component::FastCGI>, L<POE>.

=cut
