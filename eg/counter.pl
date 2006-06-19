#!/usr/bin/perl

use lib '../lib';
use strict;
use warnings;
use Coro;
use Coro::Event;
use URI::Escape;

=head1 Summary

This is pretty clearly an emulation of the Seaside tutorial.
Except the overhead for seaside is a bit bigger than this...
I'd say. There is no smoke or mirrors here, just the raw
code. We even implement our own 'prompt'...

=cut

use Continuity;
my $server = new Continuity;

Event::loop();


# Ask a question and keep asking until they answer
sub prompt {
  my ($request, $msg, @ops) = @_;
  $request->print("$msg<br>");
  foreach my $option (@ops) {
    my $uri_option = uri_escape($option);
    $request->print(qq{<a href="?option=$uri_option">$option</a><br>});
  }
  my $option = $request->next->param('option');
  print STDERR "*** Got option: $option\n";
  return $option || prompt($request, $msg, @ops);
}

sub main {
  my $request = shift;
  # When we are first called we get a chance to initialize stuff
  my $count = 0;

  # After we're done with that we enter a loop. Forever.
  while(1) {
    print STDERR "Just about to suspend...\n";
    my $add = $request->next->param('add');
    print STDERR "*** Just grabed next param\n";
    if($count >= 0 && $count + $add < 0) {
      my $choice = prompt($request, "Do you really want to GO NEGATIVE?", "Yes", "No");
      print STDERR "... again, they chose $choice\n";
      $add = 0 if $choice eq 'No';
    }
    $count += $add;
    $request->print(qq{
      Count: $count<br>
      <a href="?add=1">++</a> &nbsp;&nbsp; <a href="?add=-1">--</a><br>
    });
    if($count == 42) {
      $request->print("<h1>The Answer to Life, The Universe, and Everything</h1>");
    }
  }
}

1;

