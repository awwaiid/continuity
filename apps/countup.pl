#!/usr/bin/perl

use strict;
use lib '..';
use Continuity::Server::Simple;
use Data::Dumper;

my $server = Continuity::Server::Simple->new(
    port => 8080,
    new_cont_sub => \&main,
    app_path => '/app',
    debug => 3,
);

$server->loop;

sub main {
  # When we are first called we get a chance to initialize stuff
  my $count = 0;

  # After we're done with that we enter a loop
  while(1) {
    my $params = $server->get_request->params;
    $count++;
    print "Count: $count\n";
    print "<pre>PARAM DUMP:\n" . Dumper($params) . "</pre>";
  }
}

main();

1;

