
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

#  my %env;
  my $in = new IO::Handle;
  my $out = new IO::Handle;
  my $err = new IO::Handle;

  $self->{fcgi_request} = FCGI::Request($in,$out,$err,\%ENV);
  $self->{in} = $in;
  $self->{out} = $out;
  $self->{err} = $err;
  $self->{env} = \%ENV;
  #print STDERR "Please contact me at: ", $self->{daemon}->url, "\n";
  print STDERR "Created FCGI::Request\n";

  return $self;
}

sub debug {
  my ($self, $level, $msg) = @_;
  if($level >= $self->{debug}) {
   print STDERR "$msg\n";
  }
}

=item mapPath($path) - map a URL path to a filesystem path

=cut

sub mapPath {
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

sub sendStatic {
  my ($self, $r, $c) = @_;
  my $path = $self->mapPath($r->url->path);
  my $file;
  if(-f $path) {
    local $\;
    open($file, $path);
    # For now we'll cheat (badly) and use file
    my $mimetype = `file -bi $path`;
    chomp $mimetype;
    # And for now we'll make a raw exception for .html
    $mimetype = 'text/html' if $path =~ /\.html$/;
    print $c "Content-type: $mimetype\r\n\r\n";
    print $c (<$file>);
    $self->debug(3, "Static send '$path', Content-type: $mimetype");
  } else {
    #$c->send_error(404)
    print $c "STATUS: 404\r\n\r\n";
  }
}

sub get_request {
  my ($self) = @_;
  print STDERR "About to get FCGI Request...\n";
  my $r = $self->{fcgi_request};
  if($r->Accept() >= 0) {
    print STDERR "Accepted FCGI request.\n";
    #my $c = \*STDOUT;
    my $content;
    my $in = $self->{in};
    local $/;
    $content = <$in>;
    my $c = $self->{out};
    my $r = Continuity::Adapt::FCGI::Request->new($self->{env}, $content);
    # TODO: Also fill in $r->content
    return ($c, $r);
  }
  return undef;
}


=back

=head1 SEE ALSO

L<Continuity>

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org>
  http://thelackthereof.org/

=head1 COPYRIGHT

  Copyright (c) 2004-2006 Brock Wilcox <awwaiid@thelackthereof.org>. All rights
  reserved.  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut

1;

