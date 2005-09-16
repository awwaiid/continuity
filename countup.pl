#!/usr/bin/perl

use strict;
use CServe;
use Data::Dumper;

sub main {
  # When we are first called we get a chance to initialize stuff
  my $count = 0;

  # After we're done with that we enter a loop
  while(1) {
    my $params = getParsedInput();
    $count++;
    print "Content-type: text/html\n\n";
    print "Count: $count\n";
    print "<pre>PARAM DUMP:\n" . Dumper($params) . "</pre>";
  }
}

# Serve this program
CServe::serve(\&main);

