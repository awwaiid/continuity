package Continuity::Adapt::PSGI;

=head1 NAME

Continuity::Adapt::PSGI - PSGI backend for Continuity

=head1 SYNOPSIS

  # Run with "plackup -s <whichever AnyEvent/Coro friendly server> demo.pl"

  # Twiggy and Corona are two AnyEvent/Coro friendly Plack servers:
  #
  #       "Twiggy is a lightweight and fast HTTP server"
  #       "Corona is a Coro based Plack web server. It uses Net::Server::Coro under the hood"

  use Continuity;

  my $server = Continuity->new( 
      adapter => Continuity::Adapt::PSGI->new,
      staticp => sub { 0 },
  );

  sub main {
    my $request = shift;
    my $i = 0;
    while(++$i) {
      $request->print("Hello number $i!");
      $request->next;
    }
  }

  $server->loop;

=cut

use strict;
use warnings;

use Continuity::Request;
use base 'Continuity::Request';

use AnyEvent;
use Coro::Channel;

sub debug_level { exists $_[1] ? $_[0]->{debug_level} = $_[1] : $_[0]->{debug_level} }

sub debug_callback { exists $_[1] ? $_[0]->{debug_callback} = $_[1] : $_[0]->{debug_callback} }

sub new {
  my $class = shift;
  bless {
    first_request => 1,
    debug_level => 1,
    debug_callback => sub { print STDERR "@_\n" },
    request_queue => Coro::Channel->new(),  # AnyEvent->condvar,          #  turns out, I can't see how to implement a reusable queue with a condvar -- sdw
    @_
  }, $class;
}

sub get_request {
  # called from Continuity's main loop (new calls start_request_loop; start_request_loop gets requests from here or whereever and passes them to the mapper)
  my ($self) = @_;
  $self->Continuity::debug(3, 'get_request called');
  my $request = $self->{request_queue}->get or die;
  return $request;
}

sub loop_hook {

    my $self = shift;

    # $server->loop calls this; plackup run .psgi files except a coderef as the last value and this lets that coderef fall out of the call to $server->loop
    # uniqe to the PSGI adapter -- a coderef that gets invoked when a request comes in

    sub {
        my $env = shift;

        # stuff $env onto a queue that get_request above pulls from; get_request is called from Continuity's main execution context/loop
        # Continuity's main execution loop invokes the Mapper to send the request across a queue to the per session execution context (creating a new one as needed)

        my $request = Continuity::Adapt::PSGI::Request->new( $env ); # make it now and send it through the queue fully formed
        $self->{request_queue}->put($request);

        $request->{response_done_watcher}->recv; # XXX should be ->wait?
        return [ $request->{response_code}, $request->{response_headers}, $request->{response_content} ];

  };

}

sub map_path {
  my $self = shift;
  my $path = shift() || '';
  # my $docroot = $self->docroot || '';
  my $docroot = Cwd::getcwd();
  $docroot .= '/' if $docroot and $docroot ne '.' and $docroot !~ m{/$};
  # some massaging, also makes it more secure
  $path =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr hex $1/ge;
  $path =~ s%//+%/%g unless $docroot;
  $path =~ s%/\.(?=/|$)%%g;
  $path =~ s%/[^/]+/\.\.(?=/|$)%%g;

  # if($path =~ m%^/?\.\.(?=/|$)%) then bad

$self->Continuity::debug(2,"path: $docroot$path\n");

  return "$docroot$path";
}


sub send_static {
  my ($self, $r) = @_;

  my $url = $r->url;
  $url =~ s{\?.*}{};
  my $path = $self->map_path($url) or do { 
       $self->Continuity::debug(1, "can't map path: " . $url);
       die;
  };

  require 'Plack::App::File';
  my $stuff = Plack::App::File->serve_path({},$path);

  ( $self->{response_code}, $self->{response_headers}, $self->{response_content} )
    = @$stuff;

}

#
#
#

package Continuity::Adapt::PSGI::Request;

use AnyEvent;

# List of cookies to send
sub cookies { exists $_[1] ? $_[0]->{cookies} = $_[1] : $_[0]->{cookies} }

# Flag, never send type
sub no_content_type { exists $_[1] ? $_[0]->{no_content_type} = $_[1] : $_[0]->{no_content_type} }

# CGI query params
sub cached_params { exists $_[1] ? $_[0]->{cached_params} = $_[1] : $_[0]->{cached_params} }

sub new {
  my ($class, $env) = @_;
  my $self = {
    response_code => 200,
    response_headers => [],
    response_content => [],
    response_done_watcher => AnyEvent->condvar,
    %$env
  };
  bless $self, $class;
  return $self;
}

sub param {
    my $self = shift; 
    my $env = { %$self };
    unless($self->cached_params) {
      use Plack::Request;
      my $req = Plack::Request->new($env);
      $self->cached_params( [ %{$req->parameters} ] );
    };
    my @params = @{ $self->cached_params };
    if(@_) {
        my @values;
        while(@_) {
          my $param = shift;
          for(my $i = 0; $i < @params; $i += 2) {
              push @values, $params[$i+1] if $params[$i] eq $param;
          }
        }
        return unless @values;
        return wantarray ? @values : $values[0];
    } else {
        return @{$self->cached_params};
    }
}

sub params {
    my $self = shift;
    $self->param;
    return @{$self->cached_params};
}

sub method {
  my ($self) = @_;
  return $self->{REQUEST_METHOD};
}

sub url {
  my ($self) = @_;
  return $self->{'psgi.url_scheme'} . '://' . $self->{HTTP_HOST} . $self->{PATH_INFO};
}

sub uri {
  my $self = shift;
  return $self->url(@_);
}

sub set_cookie {
    my $self = shift;
    my $cookie = shift;
    # record cookies and then send them the next time send_basic_header() is called and a header is sent.
    #$self->{Cookie} = $self->{Cookie} . "Set-Cookie: $cookie";
    push @{ $self->{response_headers} }, "Set-Cookie" => "$cookie";
}

sub get_cookie {
    my $self = shift;
    my $cookie_name = shift;
    my ($cookie) =  map $_->[1],
      grep $_->[0] eq $cookie_name,
      map [ m/(.*?)=(.*)/ ],
      split /; */,
      $self->{HTTP_COOKIE} || '';
    return $cookie;
}

sub immediate { }

sub send_basic_header {
    my $self = shift;
    my $cookies = $self->cookies;
    $self->cookies('');
    #$self->conn->send_basic_header;  # perhaps another flag should cover sending this, but it shouldn't be called "no_content_type"
    unless($self->no_content_type) {
      push @{ $self->{response_headers} },
           "Cache-Control" => "private, no-store, no-cache",
           "Pragma" => "no-cache",
           "Expires" => "0",
           "Content-type" => "text/html",
           #$cookies;
      ;
    }
    1;
}

sub print {
  my $self = shift;
  push @{ $self->{response_content} }, @_;

  # This is a good time to let other stuff run
  Coro::cede();

  return $self;
}

sub end_request {
  my $self = shift;

  # Signal that we are done building our response
  $self->{response_done_watcher}->send;
}

=head2 C<< $adapter->map_path($path) >>

Decodes URL-encoding in the path and attempts to guard against malice.
Returns the processed filesystem path.

=cut

1;