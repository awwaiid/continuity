


package Continuity::Server::Simple;

use strict;
use Coro::Cont;
use HTTP::Request::Params;
use base 'Continuity::Server';

sub execCont {

  my ($self, $cont, $request, $conn) = @_;

  my $prev_select = select $conn; # Should maybe do fancier trick than this

  # This should be override-able
  print "Content-type: text/html\r\n\r\n";

  $cont->($request);
  
  select $prev_select;
}

sub get_request {
  my ($self) = @_;
  yield;
  my ($request) = @_;
  return $request;
}

package HTTP::Request;

# A minor ease-of-use extension for HTTP::Request
# Given an HTTP::Request, return a nice hash of name/params
# This is really just a thin wrapper around HTTP::Request::Params
sub params {
  my ($request) = @_;
  my $parse = HTTP::Request::Params->new({ req => $request });
  my $params = $parse->params;
  return $params;
}

1;

