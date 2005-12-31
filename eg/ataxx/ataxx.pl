#!/usr/bin/perl

use strict;
use lib '../../lib';
use Continuity::Server::Simple;
use URI::Escape;
use Template;

=head1 Summary

This is pretty clearly an emulation of the Seaside tutorial.
Except the overhead for seaside is a bit bigger than this...
I'd say. There is no smoke or mirrors here, just the raw
code. We even implement our own 'prompt'...

=cut

my $server = Continuity::Server::Simple->new(
    port => 8081,
    app_path => '/app',
);

$server->loop;

my $game = [];

sub main {
  # When we are first called we get a chance to initialize stuff
  my $count = 0;
  my $board = [
    [qw( B _ _ _ _ _ R )],
    [qw( _ _ _ _ _ _ _ )],
    [qw( _ B _ _ _ _ _ )],
    [qw( _ _ _ _ _ _ _ )],
    [qw( _ _ _ _ _ _ _ )],
    [qw( _ _ _ _ _ _ _ )],
    [qw( R _ _ _ _ _ B )],
  ];

  # After we're done with that we enter a loop. Forever.
  while(1) {
    my $params = $server->get_request->params;
    my $tpl = new Template('board.html');
    $tpl->set(
      board => $board
    );
    print $tpl->render();
  }
}

1;

