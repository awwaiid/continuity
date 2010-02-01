#!/usr/bin/perl

use strict;
use lib '../lib';
use Continuity;
use AnyEvent;

$| = 1;

my $server = Continuity->new(
  query_session => 'sid',
  cookie_session => 0,
  debug_level => 2,
  port => 8080
);
$server->loop;

sub main {
  my $request = shift;

  foreach my $n (1..10) {
    print STDERR "count: $n\n";
    $request->print("count: $n\n");
    sleep 1;
  }
}

