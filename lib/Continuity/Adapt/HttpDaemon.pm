
package Continuity::Adapt::HttpDaemon;

use strict;
use HTTP::Daemon;
use HTTP::Status;

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  $self = {%$self, @_};
  bless $self, $class;

  # Set up our http daemon
  my %httpConfig = (
    LocalPort => $self->{port},
    ReuseAddr => 1,
  );

  $self->{daemon} = HTTP::Daemon->new(%httpConfig) || die;
  print STDERR "Please contact me at: ", $self->{daemon}->url, "\n";

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
    $c->send_error(404)
  }
}

sub get_request {
  my ($self) = @_;

  if(my $c = $self->{daemon}->accept) {
    if(my $r = $c->get_request) {
      return ($c, $r);
    }
  }
  return undef;
}

1;

