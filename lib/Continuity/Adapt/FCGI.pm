
package Continuity::Adapt::FCGI;

use strict;
use FCGI;
use HTTP::Status;
use Continuity::Adapt::FCGI::Request;
use IO::Handle;

=head1 NAME

Continuity::Adapt::FCGI - Use HTTP::Daemon as a continuation server

=head1 DESCRIPTION

This is the default and reference adaptor for L<Continuity>. An adaptor
interfaces between the continuation server (L<Continuity::Server>) and the web
server (HTTP::Daemon, FastCGI, etc).

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

sub new_requestHolder {
  my ($self, @ops) = @_;
  my $holder = Continuity::Adapt::FCGI::RequestHolder->new( @ops );
  return $holder;
}

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

  print STDERR "Getting next FCGI Request...\n";

  my $r = $self->{fcgi_request};
  if($r->Accept() >= 0) {
    print STDERR "Accepted FCGI request.\n";
    #return Continuity::Adapt::FCGI::Request->new(
    my $request = Continuity::Adapt::FCGI::Request->new(
      fcgi_request => $r,
    );
    return $request;
  }
  return undef;
}


=back

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

