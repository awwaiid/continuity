#!/usr/bin/perl

use strict;
use Continuity::Server;
use Continuity::Client::CGI;
use URI::Escape;

=head1 Summary

This is pretty clearly an emulation of the Seaside tutorial.
Except the overhead for seaside is a bit bigger than this...
I'd say. There is no smoke or mirrors here, just the raw
code. We even implement our own 'prompt'...

=cut

my $cserver = Continuity::Server->new(
    port => 8080,
    newContinuationSub => \&main,
    # sdw: mapper => \&foo (or mapper => $ob), etc
    app_path => '/app', # all other requests go through the static sender by default
);

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
  #my $request = shift; # sdw -- passed implicitly the first time this is called
  # We get to initialize if we like, and the first call to yield actually accepts the first new request, eh?

  # When we are first called we get a chance to initialize stuff
  my $count = 0;

  # After we're done with that we enter a loop
  while(1) {
    #my $request = $request->next_request;  # sdw -- or something. not sure about a good name. this is where the 'yield' happens.
    #my $params = $request->params;         # sdw -- or maybe params should be directly accessible through $request
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


$cserver->loop(); # rbw: an alias to Event::loop :)


1;

