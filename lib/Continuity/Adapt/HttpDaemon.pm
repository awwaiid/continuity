
package Continuity::Adapt::HttpDaemon;

use strict;
use warnings;  # XXX dev

use Continuity::Request;
use base 'Continuity::Request';

use Continuity::RequestHolder;

use IO::Handle;
use Cwd;

use HTTP::Daemon; 
use HTTP::Status;
use LWP::MediaTypes qw(add_type);


# HTTP::Daemon::send_file_response uses LWP::MediaTypes to guess the
# Content-Type of a file.  Unfortunately, its list of known extensions is
# rather anemic so we're adding a few more.
add_type('image/png'       => qw(png));
add_type('text/css'        => qw(css));
add_type('text/javascript' => qw(js));

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
            my $socket_read_event = Coro::Event->io(fd => fileno $self, poll => 'r', ); # XXX should create this once per call rather than ocne per EGAIN
            $socket_read_event->next;
            $socket_read_event->cancel;
            goto try_again; 
        } else {
            return;
        }
    }

    package HTTP::Daemon::ClientConn;

    no warnings; # Don't warn for this override (this should be narrowed)

    sub _need_more {   
        my $self = shift;
        my $e = Coro::Event->io(fd => fileno $self, poll => 'r', $_[1] ? ( timeout => $_[1] ) : ( ), );
        $e->next;
        $e->cancel;
        my $n = sysread($self, $_[0], 2048, length($_[0]));
        $self->reason(defined($n) ? "Client closed" : "sysread: $!") unless $n;
        $n;
    }   

};

=head1 NAME

Continuity::Adapt::HttpDaemon - Use HTTP::Daemon to get HTTP requests

Continuity::Adapt::HttpDaemon::Request - an HTTP::Daemon based request

=head1 DESCRIPTION

This is the default and reference HTTP adaptor for L<Continuity>. It comes in
two parts, the server connector and the request interface.

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
    server => delete $args{server},
    no_content_type => delete $args{no_content_type},
    cookies => '',
  }, $class;

  # Set up our http daemon
  $self->{daemon} = HTTP::Daemon->new(
    ReuseAddr => 1,
    %args,
  ) or die $@;

  $self->{docroot} = Cwd::getcwd() if $self->{docroot} eq '.' or $self->{docroot} eq './';

  STDERR->print("Please contact me at: ", $self->{daemon}->url, "\n");

  return $self;
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
      http_request => $r,
      no_content_type => $self->{no_content_type},
    );
  }
}

=head2 C<< $adapter->map_path($path) >>

Decodes URL-encoding in the path and attempts to guard against malice.
Returns the processed path.

=cut

sub map_path {
  my $self = shift;
  my $path = shift() || '';
  my $docroot = $self->{docroot} || '';
  $docroot .= '/' if $docroot and $docroot ne '.' and $docroot !~ m{/$};
  # some massaging, also makes it more secure
  $path =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr hex $1/ge;
  $path =~ s%//+%/%g unless $docroot;
  $path =~ s%/\.(?=/|$)%%g;
  $path =~ s%/[^/]+/\.\.(?=/|$)%%g;

  # if($path =~ m%^/?\.\.(?=/|$)%) then bad

STDERR->print("path: $docroot$path\n");

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
  my $url = $r->url;
  $url =~ s{\?.*}{};
  my $path = $self->map_path($url) or do { 
       $self->debug(1, "can't map path: " . $url); $c->send_error(404); return; 
  };
  unless (-f $path) {
      $c->send_error(404);
      return;
  }
  $c->send_file_response($path);
  $self->debug(3, "Static send '$path'");
}

sub debug {
  my ($self, $level, $msg) = @_;
  if(defined $self->{debug} and $level >= $self->{debug}) {
    STDERR->print("$msg\n"); 
  } 
} 

#
#
#
#

package Continuity::Adapt::HttpDaemon::Request;

use strict;
use vars qw( $AUTOLOAD );

=for comment

See L<Continuity::Request> for API documentation.

This is what gets passed through a queue to coroutines when new requests for
them come in. It needs to encapsulate:

*  The connection filehandle
*  CGI parameters cache

XXX todo: understands GET parameters and POST in
application/x-www-form-urlencoded format, but not POST data in
multipart/form-data format.  Use the AsCGI thing if you actually really need
that (it's used for file uploads).
# XXX check request content-type, if it isn't x-form-data then throw an error
# XXX pass in multiple param names, get back multiple param values

Delegates requests off to the request object it was initialized from.

In other words: Continuity::Adapt::HttpDaemon is the ongoing running HttpDaemon
process, and Continuity::Adapt::HttpDaemon::Request is individual requests sent
through.

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless { @_ }, $class;
    eval { $self->{conn}->isa('HTTP::Daemon::ClientConn') } or warn "\$self->{conn} isn't an HTTP::Daemon::ClientConn";
    eval { $self->{http_request}->isa('HTTP::Request') } or warn "\$self->{http_request} isn't an HTTP::Request";
    STDERR->print( "\n====== Got new request ======\n"
               . "       Conn: $self->{conn}\n"
               . "    Request: $self\n"
    );
    return $self;
}

sub param {
    my $self = shift; 
    my $req = $self->{http_request};
    my @params = @{ $self->{params} ||= do {
        my $in = $req->uri; $in .= '&' . $req->content if $req->content;
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

sub end_request {
    my $self = shift;
    $self->{write_event}->cancel if $self->{write_event};
    $self->{conn}->close if $self->{conn};
}

sub set_cookie {
    my $self = shift;
    my $cookie = shift;
    # record cookies and then send them the next time send_basic_header() is called and a header is sent.
    $self->{cookies} .= "Set-Cookie: $cookie\r\n";
}

sub send_basic_header {
    my $self = shift;
    my $cookies = $self->{cookies};
    $self->{cookies} = '';
    $self->{conn}->send_basic_header;  # perhaps another flag should cover sending this, but it shouldn't be called "no_content_type"
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

sub print { 
    my $self = shift; 
    $self->{write_event} ||= Coro::Event->io(fd => fileno $self->{conn}, poll => 'w', );
    my $e = $self->{write_event};
    if(length $_[0] > 4096) {
        while(@_) { 
            my $x = shift;
            while(length $x > 4096) { $e->next; $self->{conn}->print(substr $x, 0, 4096, ''); }
            $e->next; $self->{conn}->print($x) 
        }
    } else {
        $e->next; $self->{conn}->print(@_); 
    }
    return 1;
}

sub uri { $_[0]->{http_request}->uri(); }

# sub query_string { $_[0]->{http_request}->query_string(); } # nope, doesn't exist in HTTP::Headers

sub immediate { }

sub conn :lvalue { $_[0]->{conn} } # private

sub http_request :lvalue { $_[0]->{http_request} } # private

# If we don't know how to do something, pass it on to the current http_request

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


1;

