
package CServe;

use strict;
use Coro::Cont;
use HTTP::Daemon;
use HTTP::Status;

# Take a sub ref and give back a continuation. Just a shortcut
sub mkcont {
  my ($func) = @_;
  my $cont = csub { $func->(@_) };
  return $cont;
}

sub serve {
  my ($appref) = @_;
  my $app = mkcont($appref);

  my $d = HTTP::Daemon->new(LocalPort => 8081) || die;
  print "Please contact me at: ", $d->url, "\n";

  # We call the app the first time to let it initialize
  &$app();

  while (my $c = $d->accept) {
    #while (my $r = $c->get_request) { # I don't understand the while loop
                                       # in the original example :(
    if(my $r = $c->get_request) {
      if(($r->method eq 'GET' || $r->method eq 'POST')
        && $r->url->path =~ /^\/app/) {
        my $code = RC_OK;
        $c->send_basic_header();
        select $c;
        print "Content-type: text/html\r\n\r\n";
        $app->($r);
      } else {
        $c->send_error(RC_NOT_FOUND)
      }
    }
    $c->close;
    undef($c);
  }
}

1;

