package Continuity::Adapt::Plack;

=head1 NAME

Continuity::Adapt::Plack - Plack (PSGI) backend for Continuity

=head1 SYNOPSIS

  use Continuity;
  use Continuity::Adapt::Plack;

  my $server = Continuity->new(
    adapter => Continuity::Adapt::Plack->new( impl => 'Standalone' )
  );
  $server->loop;

  sub main {
    my $request = shift;
    my $i = 0;
    while($i++) {
      $request->print("Hello number $i!");
      $request->next;
    }
  }

=cut

use lib '/home/awwaiid/projects/perl/third-party/Plack/lib';
use strict;
use warnings;  # XXX dev
use Continuity::Request;
use base 'Continuity::Request';
#use Continuity::RequestHolder;
use Plack::Loader;
use Coro::Generator;

sub new {
  my $class = shift;
  my $self = {
    impl => 'standalone', # Default to Plack::Impl::Standalone
    @_
  };
  bless $self, $class;

  my $plack = Plack::Loader->auto( impl => $self->{impl} );
  $self->{run_plack} = generator { $plack->run( sub {
    print STDERR "Plack handler: figuring stuff out\n";
    my $response = $self->got_request(@_);
    print STDERR "Plack Handler: returning response\n";
    return $response;
  } ) };

  return $self;
}

sub get_request {
  my ($self) = @_;
  print STDERR "Calling run_plack...\n";
  my $request = $self->{run_plack}->();
  print STDERR "Back from run_plack! returning request\n";
  return $request;
}

sub got_request {
  my ($self, $env) = @_;
  my $request = Continuity::Adapt::Plack::Request->new( $env );
  print STDERR "Got request $request, yielding\n";
  yield $request;
  print STDERR "back from yield, sending response\n";
  my $response = $request->get_response;
  use Data::Dumper;
  print STDERR "Response struct: " . Dumper($response);
  return $response;
}

package Continuity::Adapt::Plack::Request;

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
    %$env
  };
  bless $self, $class;
  use Data::Dumper;
  print STDERR "Req: " . Dumper($self);
  return $self;
}

sub param {
    my $self = shift; 
    unless($self->cached_params) {
      $self->cached_params( do {
        my $in = $self->uri;
        my $content;
        $self->{'psgi.input'}->read($content, 2048);
        $in .= '&' . $content if $content;
        $in =~ s{^.*\?}{};
        my @params;
        for(split/[&]/, $in) { 
            tr/+/ /; 
            s{%(..)}{pack('c',hex($1))}ge; 
            my($k, $v); ($k, $v) = m/(.*?)=(.*)/s or ($k, $v) = ($_, 1);
            push @params, $k, $v; 
        };
        \@params;
      });
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
  return $self;
}

sub end_request { }
    # my $self = shift;
    # $self->write_event->cancel if $self->write_event;
    # $self->conn->close if $self->conn;
# }

1;

