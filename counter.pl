#!/usr/bin/perl

use strict;
use CServe;
use URI::Escape;

# Ask a question and keep asking until they answer
sub prompt {
  my ($msg, @ops) = @_;
  print "$msg<br>";
  foreach my $option (@ops) {
    my $uri_option = uri_escape($option);
    print qq{<a href="?option=$uri_option">$option</a><br>};
  }
  my $params = getParsedInput();
  my $option = $params->{option};
  return $option || prompt($msg, @ops);
}

sub main {
  # When we are first called we get a chance to initialize stuff
  my $count = 0;

  # After we're done with that we enter a loop
  while(1) {
    my $params = getParsedInput();
    my $add = $params->{add};
    if($count >= 0 && $count + $add < 0) {
      my $choice = prompt("Do you really want to GO NEGATIVE?",
        "Yes", "No");
      $add = 0 if $choice eq 'No';
    }
    $count += $add;
    print qq{
      Count: $count<br>
      <a href="?add=1">++</a>
      &nbsp;&nbsp;
      <a href="?add=-1">--</a>
    };
    if($count == 42) {
      print "<h1>The Answer To Life, The Universe, and Everything</h1>";
    }

  }
}

# Serve this program
CServe::serve(\&main);

