
package CServe;

use strict;
use Coro::Cont;
use HTTP::Daemon;
use HTTP::Status;
use IO::Capture::Stdout;

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
      if($r->method eq 'GET' || $r->method eq 'POST') {
        my $code = RC_OK;
        $c->send_basic_header();
        $capture = IO::Capture::Stdout->new();
        $capture->
        my $status = &$app($r);
        print $c $response;
      } else {
        $c->send_error(RC_NOT_FOUND)
      }
    }
    $c->close;
    undef($c);
  }
}

1;

