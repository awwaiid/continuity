#!/usr/bin/perl
use lib '../lib';
use strict;
use warnings;
use Coro;
use Coro::Event;

use Continuity;
my $server = new Continuity(
  path_session => 1
);

sub main {
  my $request = shift;
STDERR->print(__FILE__, ' ', __LINE__, "\n");
  # must do a substr to chop the leading '/'
  my $name = substr($request->{request}->url->path, 1) || 'World';
  $request->print("Hello, $name!");
STDERR->print(__FILE__, ' ', __LINE__, "\n");
  $request->next;
STDERR->print(__FILE__, ' ', __LINE__, "\n");
  $name = substr($request->{request}->url->path, 1) || 'World';
  $request->print("Hello to you too, $name!");
STDERR->print(__FILE__, ' ', __LINE__, "\n");
}

Event::loop();
