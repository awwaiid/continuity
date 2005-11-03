
package CServe::Client;

use strict;
use Coro::Cont;
use HTTP::Request::Params;

use base 'Exporter';
use vars qw( @EXPORT );
@EXPORT = qw( getParsedInput );

sub splitHashify {
  my ($key, $val) = @_;
  return $val;
}

# I like my inputs split up into hashes
sub getParsedInput {
  print @_;
  yield;
  my ($r) = @_;
  my $params = getParams($r);
  foreach my $key (keys %$params) {
    if($key =~ /:|\[/) {
      my (@keys) = split /:|\[|\]\[|\]/, $key;
      my $val = $params->{$key};
      my $t = $params;
      my $key = pop @keys;
      while(my $k = shift @keys) {
        $t->{$k} = $t->{$k} || {};
        $t = $t->{$k};
      }
      $t->{$key} = $val;
    }
  }
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

