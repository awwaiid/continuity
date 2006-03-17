#!/usr/bin/perl

use strict;
use FCGI;
use Data::Dumper;

my $count = 0;
my $r = FCGI::Request();

while($r->Accept() >= 0) {
  my $me = `whoami`;
  print "Content-type: text/html\r\n\r\n";
  print "<pre>";
  print "Count: ",($count+=3),"\n";
  print "Me: $me\n";
  print "Env: " . Dumper(\%ENV) . "\n";
}

