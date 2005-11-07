#!/usr/bin/perl

use strict;
use Continuity::Client::CGI;
use Data::Dumper;

sub main {
  # When we are first called we get a chance to initialize stuff
  my $count = 0;

  # After we're done with that we enter a loop
  while(1) {
    $count++;
    print "Count: $count\n";
    print "<pre>PARAM DUMP:\n" . Dumper($params) . "</pre>";
    my $params = getParsedInput();
  }
}

main();

1;

