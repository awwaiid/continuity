#!/usr/bin/perl

use strict;
use Coro::Cont;

sub mkcont {
  my ($func) = @_;
  my $cont = csub { &$func(@_) };
  return $cont;
}

sub main {
  my $count = 0;
  while(1) {
    $count++;
    my $out = "Count: $count";
    yield $out;
  }
}

my $main = mkcont(\&main);

use HTTP::Daemon;
use HTTP::Status;

my $d = HTTP::Daemon->new(LocalPort => 8080) || die;
print "Please contact me at: ", $d->url, "\n";

while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
        if(($r->method eq 'GET'
          || $r->method eq 'POST')
          && $r->url->path eq "/xyzzy") {
            my $code = RC_OK;
            my $content = &$main();
            my $r = HTTP::Response->new($code);
            $r->headers('content-type' => 'text/html');
            $r->content($content);

            $c->send_response($r);

            # remember, this is *not* recommended practice :-)
            #$c->send_file_response("/etc/passwd");
        }
        else {
            $c->send_error(RC_FORBIDDEN)
        }
    }
    $c->close;
    undef($c);
}

