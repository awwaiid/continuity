#!/usr/bin/perl

use lib '../lib';
use strict;
use warnings;
use Continuity;

my $peeker = new Peeker;

my $server = new Continuity(
      port => 8080,
      ip_session => 0,
      cookie_session => 'sid',
      path_session => 1,
);
$server->loop;

sub getNum {
  my $request = shift;
  $request->print( qq{
    Enter Guess: <input name="num" id=num>
    <script>document.getElementById('num').focus()</script>
    </form>
    </body>
    </html>
  });
  $request = $request->next;
  my $num = $request->param('num');
  return $num;
}


sub peek {
  my ($request) = @_;
  while(1) {
    my $session_id = $request->session_id;
    my $mapper = $server->{mapper};
    my $sessions = $mapper->{sessions};
    my $session_count = scalar keys %$sessions;
    $request->print("Session count: $session_count<br>");
    my $vars;
    foreach my $sess (keys %$sessions) {
      next unless $sess =~ /^\.\./;
      $sessions->{$sess}->put($peeker);
      Coro::cede;
      $request->print("$sess secret number: " . ${$peeker->{v}->{'$number'}} . "<br>\n");
    }
    $request->next;
  }
}

sub main {
  my $request = shift;
  $request->next;

  my $path = $request->request->url->path;
  print STDERR "Path: '$path'\n";

  # If this is a request for the pushtream, then give them that
  if($path =~ /^\/peek/) {
    peek($request);
  }

  while(1) {
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
      do {
        $request->print($out);
        $guess = getNum($request);
      } until ($guess > 0);
      $out .= "It is smaller than $guess.<br>\n" if $guess > $number;
      $out .= "It is bigger than $guess.<br>\n" if $guess < $number;
    } until ($guess == $number);
    $request->print("You got it! My number was in fact $number.<br>\n");
    $request->print("It took you $tries tries.<br>\n");
    $request->print('<a href="/">Try Again</a>');
    $request->next;
}}

package Peeker;
use PadWalker qw(peek_my);
use Data::Dumper;

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self;
}

sub immediate {
  my ($self) = @_;
  STDERR->print("PEEKER ($self) called!\n");
  $self->{v} = peek_my(3);
  STDERR->print("Peeked at: " . Dumper($self->{v}) . "\n");
  return 1;
}

sub end_request { }

1;

