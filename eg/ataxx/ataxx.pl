#!/usr/bin/perl

use strict;
use lib '../../lib';
use Continuity::Server::Simple;
use Template;

my $server = Continuity::Server::Simple->new(
    port => 8081,
    app_path => '/app',
);

$server->loop;

my $games = [];

sub new_game {
  my $game = {
    board => [
      [qw( B _ _ _ _ _ R )],
      [qw( _ _ _ _ _ _ _ )],
      [qw( _ _ _ _ _ _ _ )],
      [qw( _ _ _ _ _ _ _ )],
      [qw( _ _ _ _ _ _ _ )],
      [qw( _ _ _ _ _ _ _ )],
      [qw( R _ _ _ _ _ B )],
    ],
    red_score => 0,
    blue_score => 0,
    player => 'B',
    moves => [],
    selected => undef,
  };
  push @$games, $game;
  return $game;
}

sub is_legal_move {
  my ($game, $from_x, $from_y, $to_x, $to_y) = @_;
  return 1;
}

#sub select_from {
#  my ($game) = @_;
#  my ($x, $y);

sub main {
  # When we are first called we get a chance to initialize stuff
  my $game = new_game();

  my ($x, $y);
  # After we're done with that we enter a loop. Forever.
  while(1) {
    my $params = $server->get_request->params;
    if((defined $params->{x}) && (defined $params->{y})) {
      ($x, $y) = @$params{qw(x y)}; # My first hash slice!
      print STDERR "Move: $x, $y\n";
      $game->{board}[$x][$y] = $game->{player};
      $game->{player} = $game->{player} eq 'B' ? 'R' : 'B';
      $game->{selected} = [$x, $y];
    }
    my $tpl = new Template('board.html');
    $tpl->set( %$game );
    print $tpl->render();
  }
}

1;

