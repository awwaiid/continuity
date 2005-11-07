#!/usr/bin/perl

use strict;
use Continuity::Client::CGI;
use PHP::Interpreter;

sub main {
  my $p = PHP::Interpreter->new();
  print `pwd`;
  print "hrm.\n";
  $p->include('./docs/bleh.php');
}

main();

1;

