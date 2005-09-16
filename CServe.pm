
package CServe;

use strict;
use Coro::Cont;
use HTTP::Daemon;
use HTTP::Status;
use HTTP::Request::Params;

use base 'Exporter';
use vars qw( @EXPORT );
@EXPORT = qw( getParsedInput );

sub getParsedInput {
  yield;
  my ($r) = @_;
  my $params = getParams($r);
  return $params;
}

# Take a sub ref and give back a continuation. Just a shortcut
sub mkcont {
  my ($func) = @_;
  my $cont = csub { &$func(@_) };
  return $cont;
}

# Given an HTTP::Request, return a nice hash of name/params
# This is really just a thin wrapper around HTTP::Request::Params
sub getParams {
  my ($request) = @_;
  my $parse = HTTP::Request::Params->new({ req => $request });
  my $params = $parse->params;
  return $params;
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
        &$app($r);
      } else {
        $c->send_error(RC_NOT_FOUND)
      }
    }
    $c->close;
    undef($c);
  }
}

1;

