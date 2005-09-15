#!/usr/bin/perl

use strict;
use Coro::Cont;

# Take a sub ref and give back a continuation
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

use vars qw( %application );

%application = (
  '/countup' => \&main,
);

sub init {
  foreach my $appname (keys %application) {
    $application{$appname} = mkcont($application{$appname});
  }
}

init();

use HTTP::Daemon;
use HTTP::Status;

my $d = HTTP::Daemon->new(LocalPort => 8081) || die;
print "Please contact me at: ", $d->url, "\n";

while (my $c = $d->accept) {
    while (my $r = $c->get_request) {
        my $app;
        if(($r->method eq 'GET' || $r->method eq 'POST')
          && ($app = $application{$r->url->path})) {
            my $code = RC_OK;
            my $content = &$app();
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

