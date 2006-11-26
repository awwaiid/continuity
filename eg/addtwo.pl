#!/usr/bin/perl

use strict;
use lib '../lib';
use Continuity;

my $server = new Continuity(port => 16001);
$server->loop;

sub main {
  my $request = shift;
  $request->next; # Get the initial request
  my ($num1, $num2);
  do {
  $request->print(qq{
    <form>
      Enter first number:
      <input type=text name=num><input type=submit>
    </form>
  });
  $request->next;
  $num1 = $request->param('num');

  } while($num1 !~ /\d+/);
  $request->print(qq{
    <form>
      Enter second number:
      <input type=text name=num><input type=submit>
    </form>
  });
  my $num2 = $request->next->param('num');
  my $sum = $num1 + $num2;
  $request->print(qq{
    <h2>The sum of $num1 and $num2 is $sum!</h2>
  });
}

