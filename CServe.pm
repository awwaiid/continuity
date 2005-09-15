
package CServe;

use strict;
use Coro::Cont;
use HTTP::Daemon;
use HTTP::Status;

# Take a sub ref and give back a continuation
sub mkcont {
  my ($func) = @_;
  my $cont = csub { &$func(@_) };
  return $cont;
}

sub serve {
  my ($appref) = @_;
  my $app = mkcont($appref);

  my $d = HTTP::Daemon->new(LocalPort => 8081) || die;
  print "Please contact me at: ", $d->url, "\n";

  while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
      my $app;
      if($r->method eq 'GET' || $r->method eq 'POST') {
        my $code = RC_OK;
        my $content = &$app($r);
        my $r = HTTP::Response->new($code);
        $r->headers('content-type' => 'text/html');
        $r->content($content);
        $c->send_response($r);
      } else {
          $c->send_error(RC_NOT_FOUND)
      }
      $c->force_last_request;
    }
    $c->close;
    undef($c);
  }
}

1;

