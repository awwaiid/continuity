#!/usr/bin/perl

use strict;
use CServe::Client;
use PHP::Interpreter;

sub main {
  my $p = PHP::Interpreter->new();
  print `pwd`;
  print "hrm.\n";
  $p->include('./docs/bleh.php');
}

main();

1;

