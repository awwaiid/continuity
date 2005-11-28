#!/usr/bin/perl

use strict;
use Continuity::Client::CGI;

sub getNum {
 print qq{
    Enter Guess: <input name="num">
    <input type=submit value="Guess"><br>
  };
  my $f = getParsedInput();
  return $f->{'num'};
}

sub main {
  my $guess;
  my $number = int(rand(100)) + 1;
  my $tries = 0;
  my $out = qq{
    <form>
      Hi! I'm thinking of a number from 1 to 100... can you guess it?<br>\n";
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
  print '<a href="guess.pl">Play Again</a>';
}

main();

1;

