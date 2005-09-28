
package CServe::Client;

use strict;
use Coro::Cont;
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

# Given an HTTP::Request, return a nice hash of name/params
# This is really just a thin wrapper around HTTP::Request::Params
sub getParams {
  my ($request) = @_;
  my $parse = HTTP::Request::Params->new({ req => $request });
  my $params = $parse->params;
  return $params;
}

1;

