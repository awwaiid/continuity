
package Continuity::Adapt::HttpDaemon;

use strict;
use warnings;  # XXX dev

use Coro;
use Coro::Cont;
use Coro::Socket;

use IO::Handle;

use HTTP::Daemon; BEGIN { @HTTP::Daemon::ISA = @HTTP::Daemon::ClientConn = ('Coro::Socket'); };
use HTTP::Status;

=head1 NAME

Continuity::Adapt::HttpDaemon - Use HTTP::Daemon as a continuation server

=head1 DESCRIPTION

This is the default and reference adaptor for L<Continuity>. An adaptor
interfaces between the continuation server (L<Continuity::Server>) and the web
server (HTTP::Daemon, FastCGI, etc).

  XXX needs an abstract parent class if this is a reference implementation and not itself a base class
  XXX plays stupid inheritance tricks because HTTP::Daemon thinks it's cool to inherit rather than delegate
  XXX mapper and adapter now have server=>$self passed in from the server, and config is delegated to rather than copied

=head1 METHODS

=head2 $server = Continuity::Adapt::HttpDaemon->new(...)

Create a new continuation adaptor and HTTP::Daemon. This actually starts the
HTTP server which is embeded.

=cut

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  $self = { @_ };
  bless $self, $class;

  # Set up our http daemon
  my %httpConfig = (
    LocalPort => $self->{server}->{port},
    ReuseAddr => 1,
  );

  $self->{daemon} = HTTP::Daemon->new(%httpConfig) or die;
  print STDERR "Please contact me at: ", $self->{daemon}->url, "\n";

  return $self;
}

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

We cheat here... use 'magic' to get mimetype and send that. 
Then the binary file.
I don't think we're well enough protected against shell meta characters... ever.  XXX Use a pipe with a 3-arg open instead to bypass shell if we're going to use magic.

=cut

sub send_static {
  my ($self, $r, $c) = @_;
  my $path = $self->mapPath($r->url->path);
  my $file;
  if(-f $path) {
    local $/;
    open $file, '<', $path or return;
    # For now we'll cheat (badly) and use file
    my $mimetype = `file -bi $path`; # XXX
    chomp $mimetype;
    # And for now we'll make a raw exception for .html
    $mimetype = 'text/html' if $path =~ /\.html$/;
    print $c "Content-type: $mimetype\r\n\r\n";
    print $c (<$file>);
    $self->{server}->debug(3, "Static send '$path', Content-type: $mimetype");
  } else {
    $c->send_error(404)
  }
}

=head2 mapPath($path) - map a URL path to a filesystem path

=cut

sub get_request {
  my ($self) = @_;

  if(my $c = $self->{daemon}->accept) {
    if(my $r = $c->get_request) {
      return ($c, $r);
    }
    close $c;
  }
  return ();
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

