#!/usr/bin/perl

use strict;
use lib '../lib';
use Continuity;

my $count = 0;

Continuity->new->loop;

sub main {
  my $req = shift;
  while(1) {
    $req->print("Hello! $count");
    $count++;
    $req->next;
  }
}

