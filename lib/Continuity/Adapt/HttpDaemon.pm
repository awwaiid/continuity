
=for comment

Bleah.  Mucking around in internals of Coro::Socket and IO::Socket::INET is going very badly.

Let's just use Event to add Coro friendliness to just the plain old IO::Socket::INET that
gets created by HTTP::Daemon when it's inheritance isn't messed with.  That should just
be a matter of creating some read event handles and waiting on them.

=cut

package Continuity::Adapt::HttpDaemon;

use strict;
use warnings;  # XXX dev

use Coro;
use Coro::Socket;

use IO::Handle;

use HTTP::Daemon; 

do {

    package HTTP::Daemon;

    sub xx_accept {   
        # it already had one of these, but Coro::Socket locks the accept($alternate_package) feature
        my $self = shift;
        my $pkg = shift || "HTTP::Daemon::ClientConn";
STDERR->print(__FILE__, ' ', __LINE__, "\n");
        # $_[0]->readable or return;
        # my ($sock, $peer) = Coro::Socket->can('accept')->($self);
        Coro::Event->io(fd => fileno $self, poll => 'r', )->next;
        (my $sock, my $peer) = $self->accept();
        # $sock = $self->new_from_fh($fh);
        # return unless $!{EAGAIN};
STDERR->print(__FILE__, ' ', __LINE__, " err: $@ $!\n");
        if ($sock) {
            bless $sock, $pkg; # evil rebless
            ${*$sock}{'httpd_daemon'} = $self;
            return wantarray ? ($sock, $peer) : $sock;
        } else {
            return;
        }
    }

    package HTTP::Daemon::ClientConn;

sub _need_more
{   
    my $self = shift;
    #my($buf,$timeout,$fdset) = @_;
    print STDERR "sysread()\n";
    Coro::Event->io(fd => fileno $self, poll => 'r', $_[1] ? ( timeout => $_[1] ) : ( ), )->next;
    my $n = sysread($self, $_[0], 2048, length($_[0]));
    print STDERR "sysread() done: $@ $!\n";
    $self->reason(defined($n) ? "Client closed" : "sysread: $!") unless $n;
    $n;
}   

    sub xx__need_more {
        my $self = shift;
        if ($_[1]) {
            my($timeout, $fdset) = @_[1,2];
            $self->timeout($timeout); # Coro::Handle method
            #print STDERR "select(,,,$timeout)\n" if $DEBUG;
            #my $n = select($fdset,undef,undef,$timeout);
            #unless ($n) {
            #    $self->reason(defined($n) ? "Timeout" : "select: $!");
            #    return;
            #}
        }
print STDERR "sysread() start\n";
        $self->readable(); # Coro::Handle method
        my $n = $self->recv($_[0], 2048);
print STDERR "sysread() finished\n";
        $self->reason(defined($n) ? "Client closed" : "sysread: $!") unless $n;
        $n;
    }

};


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
  my $self = bless { @_ }, $class;

  # Set up our http daemon
  my %httpConfig = (
    LocalPort => $self->{server}->{port},
    ReuseAddr => 1,
  );

  HTTP::Daemon->new(%httpConfig) or die $@;
  $self->{daemon} = HTTP::Daemon->new(%httpConfig) or die $@;
#use Data::Dumper;
STDERR->print('self-daemon: ', ref($self->{daemon})); 
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


=item send_static($c, $path) - send static file to the $c filehandle

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
    $c->send_error(404);
  }
}

=head2 get_request() - map a URL path to a filesystem path

Called in a loop from L<Contuinity::Server>.
Returns the empty list on failure, which aborts the server process.

=cut

sub get_request {
  my ($self) = @_;

STDERR->print(__FILE__, ' ', __LINE__, "\n");
  if(my $c = $self->{daemon}->accept) {
STDERR->print("debug: c is an ", ref $c, "\n");
    if(my $r = $c->get_request) {
STDERR->print(__FILE__, ' ', __LINE__, "\n");
      return ($c, $r);
STDERR->print(__FILE__, ' ', __LINE__, "\n");
    }
    close $c;
  }
STDERR->print(__FILE__, ' ', __LINE__, " err: $@ $!\n");
  return ();
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

