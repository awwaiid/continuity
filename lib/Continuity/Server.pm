
#package Coro::HTTP::Daemon;
#use HTTP::Daemon;
#use base 'Coro::Socket', 'HTTP::Daemon::ClientConn';

package Continuity::Server;

use strict;
use Coro::Cont;

use lib '.';

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  # Default docroot
  $self->{docroot} = '.';
  $self = {%$self, @_};
  bless $self, $class;
  if(!$self->{mapper}) {
    eval { use Continuity::Mapper };
    $self->{mapper} = new Continuity::Mapper(
      debug => $self->{debug},
    ); # default mapper
  }
  if($self->{new_cont_sub}) {
    $self->{mapper}->set_cont_maker_sub($self->{new_cont_sub});
  } else {
    $self->{mapper}->set_cont_maker_sub(\&::main);
  }

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


=item serve() - main serving loop

=cut

sub execCont {
  my ($self, $continuation, $r, $c) = @_;
  eval { $continuation->($r, $c) };
}

sub loop {

  my ($self) = @_;
  my $appName = $self->{app_path};

  # Don't pull these in unless we were called
  eval {
    use HTTP::Daemon;
    use HTTP::Status;
  };

  my %httpConfig = (
    LocalPort => $self->{port},
    ReuseAddr => 1,
  );

  my $d = HTTP::Daemon->new(%httpConfig) || die;
  print STDERR "Please contact me at: ", $d->url, "\n";

  while (my $c = $d->accept()) {
    if(my $r = $c->get_request) {
      if($r->method eq 'GET' || $r->method eq 'POST') {

        # Send the basic headers all the time
        $c->send_basic_header();

        # We need some way to decide if we should send static or dynamic
        # content.
        if((!$appName) || $r->url->path eq $appName) {
          $self->debug(3, "Calling map... ");
          my $continuation = $self->{mapper}->map($r, $c);
          $self->debug(3, "done mapping.");
          $self->execCont($continuation, $r, $c);
          $self->debug(1, "Error: $@") if $@; # Theoretically this will print errors??
        } else {
          $self->debug(3, "Sending static content... ");
          $self->sendStatic($r, $c);
          $self->debug(3, "done sending static content.");
        }
      } else {
        $c->send_error(RC_NOT_FOUND)
      }
    }
    $c->close;
    undef($c);
  }
}

1;

