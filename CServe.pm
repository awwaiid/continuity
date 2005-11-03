
#package Coro::HTTP::Daemon;
#use HTTP::Daemon;
#use base 'Coro::Socket', 'HTTP::Daemon::ClientConn';

package CServe;

use strict;
use Coro::Cont;
use HTTP::Daemon;
use HTTP::Status;
use Safe;

use vars qw( %httpConfig $docroot );

%httpConfig = (
  LocalPort => 8081,
  ReuseAddr => 1,
);

$docroot = '/Users/bwilcox/cserver/docs';


# Take a sub ref and give back a continuation. Just a shortcut
sub mkcont {
  my ($func) = @_;
  my $cont = csub { $func->(@_) };
  return $cont;
}

my $sessionIdCounter;
sub getSession {
  my ($request) = @_;
  #print "Headers: " . $request->as_string();
  my $cookieHeader = $request->header('Cookie');
  print "Cookie: $cookieHeader\n";
  print "sessionIdCounter: $sessionIdCounter\n";
  if($cookieHeader =~ /sessionid=(\d+)/) {
    print "Found sessionId!\n";
    return $1;
  }
  return $sessionIdCounter++;
}

my %session;
sub getSessionApp {
  my ($sessionId, $appref) = @_;
  my $app;
  if(exists $session{$sessionId}) {
    print "Found existing app\n";
    $app = $session{$sessionId};
  } else {
    print "Creating new continuation\n";
    $app = mkcont($appref);
    #print "Calling for initialization\n";
    #$app->(); # Call it once for initialization
  }
  return $app;
}

sub setSessionApp {
  my ($sessionId, $app) = @_;
  $session{$sessionId} = $app;
}

sub mapPath {
  my ($path) = @_;
   # some massaging, also makes it more secure
   $path =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr hex $1/ge;
   $path =~ s%//+%/%g;
   $path =~ s%/\.(?=/|$)%%g;
   1 while $path =~ s%/[^/]+/\.\.(?=/|$)%%;

   # if($path =~ m%^/?\.\.(?=/|$)%) then bad

  return "$docroot$path";
}

sub sendStatic {
  my ($c, $path) = @_;
  my $file;
  if(-f $path) {
    local $\;
    open($file, $path);
    $c->send_basic_header();
    select $c;
    # For now we'll cheat (badly) and use file
    my $mimetype = `file -bi $path`;
    chomp $mimetype;
    # And for now we'll make a raw exception for .html
    $mimetype = 'text/html' if $path =~ /\.html$/;
    print "Content-type: $mimetype\r\n\r\n";
    print <$file>;
    select STDOUT;
    print "Static send '$path', Content-type: $mimetype\n";
  } else {
    $c->send_error(RC_NOT_FOUND)
  }
}

sub runApp {
  my ($c, $r, $path) = @_;
  my $appref = sub { require $path };
  my $sessionId = getSession($r);
  print "Got session $sessionId\n";
  my $app = getSessionApp($sessionId, $appref);
  print "Got app\n";
  $c->send_basic_header();
  select $c;
  print "Set-Cookie: sessionid=$sessionId\r\n";
  print "Content-type: text/html\r\n\r\n";
  eval { $app->($r) };
  print STDERR $@ if $@;
  select STDOUT;
  setSessionApp($sessionId, $app);
}

sub serve {
#  my ($appref) = @_;

  my $d = HTTP::Daemon->new(%httpConfig) || die;
  print "Please contact me at: ", $d->url, "\n";

  async {
    #while (my $c = $d->accept('Coro::HTTP::Daemon')) {
    while (my $c = $d->accept()) {
      #while (my $r = $c->get_request) { # Doesn't work
      if(my $r = $c->get_request) {
        if($r->method eq 'GET' || $r->method eq 'POST') {
          my $path = mapPath($r->url->path);
          if($path =~ /\.pl$/) {
            runApp($c, $r, $path);
          } else {
            sendStatic($c, $path);
          }
        } else {
          $c->send_error(RC_NOT_FOUND)
        }
      }
      $c->close;
      undef($c);
    }
  }
}

serve();

1;

