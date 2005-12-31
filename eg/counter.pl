#!/usr/bin/perl

use strict;
use lib '../lib';
use Continuity::Server::Simple;
use URI::Escape;

=head1 Summary

This is pretty clearly an emulation of the Seaside tutorial.
Except the overhead for seaside is a bit bigger than this...
I'd say. There is no smoke or mirrors here, just the raw
code. We even implement our own 'prompt'...

=cut

my $server = Continuity::Server::Simple->new(
    port => 8081,
    app_path => '/app',
    debug => 3,
    # all other requests go through the static sender by default
    # sdw: mapper => \&foo (or mapper => $ob), etc
);

$server->loop;

# Ask a question and keep asking until they answer
sub prompt {
  my ($msg, @ops) = @_;
  print "$msg<br>";
  foreach my $option (@ops) {
    my $uri_option = uri_escape($option);
    print qq{<a href="?option=$uri_option">$option</a><br>};
  }
  my $params = $server->get_request->params;
  my $option = $params->{option};
  return $option || prompt($msg, @ops);
}

sub main {
  # When we are first called we get a chance to initialize stuff
  my $count = 0;

  # After we're done with that we enter a loop. Forever.
  while(1) {
    my $params = $server->get_request->params;
    my $add = $params->{add};
    if($count >= 0 && $count + $add < 0) {
      my $choice = prompt("Do you really want to GO NEGATIVE?", "Yes", "No");
      $add = 0 if $choice eq 'No';
    }
    $count += $add;
    print qq{
      Count: $count<br>
      <a href="?add=1">++</a> &nbsp;&nbsp; <a href="?add=-1">--</a><br>
    };
    if($count == 42) {
      print "<h1>The Answer to Life, The Universe, and Everything</h1>";
    }
  }
}

1;

