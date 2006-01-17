#!/usr/bin/perl

use strict;
use lib '../lib';
use Continuity::Server::Simple;

my $server = Continuity::Server::Simple->new(
    port => 8080,
    new_cont_sub => \&main,
    app_path => '/app',
    debug => 3,
);

$server->loop;

sub getNum {
  print qq{
    Enter Guess: <input name="num">
    </form>
    </body>
    </html>
  };
  my $f = $server->get_request->params;
  return $f->{'num'};
}

sub main {
  # Ignore the first input, it just means they are viewing us
  $server->get_request;
  my $guess;
  my $number = int(rand(100)) + 1;
  my $tries = 0;
  my $out = qq{
    <html>
      <head><title>The Guessing Game</title></head>
      <body>
        <form method=POST>
          Hi! I'm thinking of a number from 1 to 100... can you guess it?<br>
  };
  do {
    $tries++;
    print $out;
    $guess = getNum();
    $out .= "It is smaller than $guess.<br>\n" if $guess > $number;
    $out .= "It is bigger than $guess.<br>\n" if $guess < $number;
  } until ($guess == $number);
  print "You got it! My number was in fact $number.<br>\n";
  print "It took you $tries tries.<br>\n";
  print '<a href="/app">Play Again</a>';
}


1;

