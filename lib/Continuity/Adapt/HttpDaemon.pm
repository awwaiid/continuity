
package Continuity::Adapt::HttpDaemon;

use strict;
use warnings;  # XXX dev

use Coro;

use IO::Handle;

use HTTP::Daemon; 
use HTTP::Status;

use Continuity::Adapt::HttpDaemon::Request;

do {

    # HTTP::Daemon isn't Coro-friendly and attempting to diddle HTTP::Daemon's
    # inheritence to use Coro::Socket instead was a dissaster.  So, instead, we
    # provide reimplementations of just a couple of functions to make it all
    # Coro-friendly.  This kind of meddling- under-the-hood is still just
    # asking for breaking from future versions of HTTP::Daemon.

    package HTTP::Daemon;

    use Errno;
    use Fcntl uc ':default';

    no warnings; # Don't warn for this override (this should be narrowed)
    sub accept {
        my $self = shift;
        my $pkg = shift || "HTTP::Daemon::ClientConn";  
        fcntl $self, &Fcntl::F_SETFL, &Fcntl::O_NONBLOCK or die "fcntl(O_NONBLOCK): $!";
        try_again:
        my ($sock, $peer) = $self->SUPER::accept($pkg);
        if($sock) {
            ${*$sock}{'httpd_daemon'} = $self;
            return wantarray ? ($sock, $peer) : $sock;
        } elsif($!{EAGAIN}) {
            Coro::Event->io(fd => fileno $self, poll => 'r', )->next->cancel;
            goto try_again; 
        } else {
            return;
        }
    }

    package HTTP::Daemon::ClientConn;

    no warnings; # Don't warn for this override (this should be narrowed)

    sub _need_more {   
        my $self = shift;
        Coro::Event->io(fd => fileno $self, poll => 'r', $_[1] ? ( timeout => $_[1] ) : ( ), )->next->cancel;
        my $n = sysread($self, $_[0], 2048, length($_[0]));
        $self->reason(defined($n) ? "Client closed" : "sysread: $!") unless $n;
        $n;
    }   

};

=head1 NAME

Continuity::Adapt::HttpDaemon - Use HTTP::Daemon to get HTTP requests

=head1 DESCRIPTION

This is the default and reference HTTP adaptor for L<Continuity>. 

An adaptor interfaces between the continuation server (L<Continuity>) and the
web server (HTTP::Daemon, FastCGI, etc). It provides incoming HTTP requests to
the continuation server.

This adapter interfaces with L<HTTP::Daemon>.

This module was designed to be subclassed to fine-tune behavior.

=head1 METHODS

=head2 C<< $adapter = Continuity::Adapt::HttpDaemon->new(...) >>

Create a new continuation adaptor and HTTP::Daemon. This actually starts the
HTTP server, which is embeded. It takes the same arguments as the
L<HTTP::Daemon> module, and those arguments are passed along.  It also takes
the optional argument C<< docroot => '/path' >>. This adapter may then be
specified for use with the following code:

  my $server = Contuinity->new(adapter => $adapter);

This method is required for all adaptors.

=cut

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my %args = @_;
  my $self = bless { 
    docroot => delete $args{docroot},
  }, $class;

  # Set up our http daemon
  $self->{daemon} = HTTP::Daemon->new(
    ReuseAddr => 1,
    %args,
  ) or die $@;

  print STDERR "Please contact me at: ", $self->{daemon}->url, "\n";

  return $self;
}

sub new_requestHolder {
  my ($self, @ops) = @_;
  my $holder = Continuity::Adapt::HttpDaemon::RequestHolder->new( @ops );
  return $holder;
}

=head2 get_request() - map a URL path to a filesystem path

Called in a loop from L<Contuinity>.

Returns the empty list on failure, which aborts the server process.
Aside from the constructor, this is the heart of this module.

This method is required for all adaptors.

=cut

sub get_request {
  my ($self) = @_;

  # STDERR->print(__FILE__, ' ', __LINE__, "\n");
  while(1) {
    my $c = $self->{daemon}->accept or next;
    my $r = $c->get_request or next;
    return Continuity::Adapt::HttpDaemon::Request->new(
      conn => $c,
      http_request => $r
    );
  }
}

=head2 C<< $adapter->map_path($path) >>

Decodes URL-encoding in the path and attempts to guard against malice.
Returns the processed path.

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

=head2 C<< send_static($request) >>

Sends a static file off of the filesystem.

We cheat here... use 'magic' to get mimetype and send that followed by the contents of the file. 

This may be obvious, but you can't send binary data as part of the same request that you've already
sent text or HTML on, MIME aside.

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
  $self->debug(3, "Static send '$path', Content-type: $mimetype");
}

sub debug {
  my ($self, $level, $msg) = @_;
  if(defined $self->{debug} and $level >= $self->{debug}) {
    print STDERR "$msg\n"; 
  } 
} 


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

