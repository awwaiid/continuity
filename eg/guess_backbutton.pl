#!/usr/bin/perl

use strict;
use lib '../lib';
use Continuity::Server::Simple;

my $server = Continuity::Server::Simple->new(
    app_path => '/app',
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
  my $out = qq|
    <html>
      <head>
        <title>The Guessing Game</title>
        <SCRIPT SRC="ahah.js"></SCRIPT>
        <script>
          function doIt() {
            tag = document.getElementById("visited");
            text = tag.value;
            if(text == "no") {
              tag.value = "yes";
            } else {
              ahah('/app?num=back', 'content');
              //window.location = '/app?num=back';
            }
          }
        </script>
      </head>
      <body id=content onload="doIt()">
        <form method=POST>
          <input type=hidden name=visited id=visited value="no">
          Hi! I'm thinking of a number from 1 to 100... can you guess it?<br>
  |;
  do {
    $tries++;
    print $out;
    $guess = getNum();
    if($guess eq 'back') {
      $out .= "NO CHEATING!<br>\n";
      $guess = -1;
    } else {
      $out .= "It is smaller than $guess.<br>\n" if $guess > $number;
      $out .= "It is bigger than $guess.<br>\n" if $guess < $number;
    }
  } until ($guess == $number);
  print "You got it! My number was in fact $number.<br>\n";
  print "It took you $tries tries.<br>\n";
  print '<a href="/app">Play Again</a>';
}


1;

