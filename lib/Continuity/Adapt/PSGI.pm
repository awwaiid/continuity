package Continuity::Adapt::PSGI;

=head1 NAME

Continuity::Adapt::PSGI - PSGI backend for Continuity

=head1 SYNOPSIS

  # Run with "plackup -s Coro demo.pl"

  use Continuity;

  my $server = Continuity->new();
  $server->loop;

  sub main {
    my $request = shift;
    my $i = 0;
    while(++$i) {
      $request->print("Hello number $i!");
      $request->next;
    }
  }

=cut

use strict;
use warnings;
use Continuity::Request;
use base 'Continuity::Request';

sub debug_level { exists $_[1] ? $_[0]->{debug_level} = $_[1] : $_[0]->{debug_level} }

sub debug_callback { exists $_[1] ? $_[0]->{debug_callback} = $_[1] : $_[0]->{debug_callback} }

sub new {
  my $class = shift;
  my $self = {
    first_request => 1,
    debug_level => 1,
    debug_callback => sub { print STDERR "@_\n" },
    @_
  };
  bless $self, $class;
  return $self;
}

sub get_request {
  my ($self, $env) = @_;
  $self->Continuity::debug(3, 'get_request called');
  my $request = Continuity::Adapt::PSGI::Request->new( $env );
  return $request;
}

package Continuity::Adapt::PSGI::Request;

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

sub get_response {
  my $self = shift;

  # Wait for the response to be all finished
  $self->{response_done_watcher}->recv;

  return [ $self->{response_code}, $self->{response_headers}, $self->{response_content} ];
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

package Continuity;

# Override the ->loop
no warnings 'redefine';

# We don't need a request loop
sub start_request_loop { }

our $timer;

sub loop {
  my ($self) = @_;
  $self->debug(3, "Starting overridden loop");

  # This is our reaper event. It looks for expired sessions and kills them off.
  # TODO: This needs some documentation at the very least
  # async {
     # my $timeout = 300;  
     # $timeout = $self->{reap_after} if $self->{reap_after} and $self->{reap_after} < $timeout;
     # my $timer = Coro::Event->timer(interval => $timeout, );
     # while ($timer->next) {
        # $self->debug(3, "debug: loop calling reap");
        # $self->mapper->reap($self->{reap_after}) if $self->{reap_after};
     # }
  # };

  # cede once to get our reaper running
  # $self->debug(3, "Cede once for reaper");
  # cede;

  $self->debug(3, "Creating app");

  my $app = sub {

    my $env = shift;

    my $r = $self->adapter->get_request($env);
    $self->handle_request($r);
    my $response = $r->get_response(); # waits for the response to be ready
    return $response;

  };

  Coro::cede();
 
  $self->debug(3, "Returning app");
  return $app;
}

1;


