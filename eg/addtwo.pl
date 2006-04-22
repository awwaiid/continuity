#!/usr/bin/perl

use strict;
use lib '../lib';
use Continuity::Server::Simple;

my $server = Continuity::Server::Simple->new(
    port => 8081,
);

$server->loop;

sub main {
  $server->get_request;
  print qq{
    <form>
      Enter first number:
      <input type=text name=num><input type=submit>
    </form>
  };
  my $params = $server->get_request->params;
  my $num1 = $params->{num};
  print qq{
    <form>
      Enter second number:
      <input type=text name=num><input type=submit>
    </form>
  };
  $params = $server->get_request->params;
  my $num2 = $params->{num};
  my $sum = $num1 + $num2;
  print qq{
    <h2>The sum of $num1 and $num2 is $sum!</h2>
  }
}

