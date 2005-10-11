
package Coro::HTTP::Daemon;
use HTTP::Daemon;
use base 'Coro::Socket', 'HTTP::Daemon::ClientConn';

package CServe;

use strict;
use Coro::Cont;
use HTTP::Daemon;
use HTTP::Status;

use vars qw( %httpConfig );

%httpConfig = (
  LocalPort => 8081,
);

# Take a sub ref and give back a continuation. Just a shortcut
sub mkcont {
  my ($func) = @_;
  my $cont = csub { $func->(@_) };
  return $cont;
}

my $sessionIdCounter;
sub getSession {
  my ($request) = @_;
  print "Headers: " . $request->as_string();
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
    $app = $session{$sessionId};
  } else {
    $app = mkcont($appref);
    $app->(); # Call it once for initialization
  }
  return $app;
}

sub setSessionApp {
  my ($sessionId, $app) = @_;
  $session{$sessionId} = $app;
}

sub serve {
  my ($appref) = @_;

  my $d = HTTP::Daemon->new(%httpConfig) || die;
  print "Please contact me at: ", $d->url, "\n";


  async {
      print "here1\n";
    #while (my $c = $d->accept('Coro::HTTP::Daemon')) {
    while (my $c = $d->accept()) {
      print "here2\n";
      #while (my $r = $c->get_request) { # Doesn't work
      if(my $r = $c->get_request) {
        print "here3\n";
        if(($r->method eq 'GET' || $r->method eq 'POST')
          && $r->url->path =~ /^\/app/) {
          my $code = RC_OK;
          my $sessionId = getSession($r);
          my $app = getSessionApp($sessionId, $appref);
          $c->send_basic_header();
          select $c;
          print "Set-Cookie: sessionid=$sessionId\r\n";
          print "Content-type: text/html\r\n\r\n";
          $app->($r);
          select STDOUT;
          setSessionApp($sessionId, $app);
        } else {
          $c->send_error(RC_NOT_FOUND)
        }
      }
      $c->close;
      undef($c);
    }
  }
}

1;

