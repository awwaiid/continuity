#!/usr/bin/perl -w

use strict;
use lib '../lib';
use Continuity;
use Coro;
use Coro::Event;
use Data::Dumper;

# This is the A MODIFIED VERSION written by awwaiid.
# The original version was written by Merlyn,
# http://www.perlmonks.org/?node_id=200391

## I originally wrote this for a column,
## but haven't gotten around to using it yet.
## just think of an animal, and invoke it.
## It's an example of a self-learning game.
## When you choose not to continue, it'll dump out
## the data structure of knowledge it has accumulated.

my $info = "dog";

use Continuity;
my $server = new Continuity;

Event::loop();

sub main {
  my $request = shift;
  # Ignore the first input, it just indicates that they are viewing the page
  $request->next;
  {
    try($request, $info);
    redo if (yes("play again?"));
  }
  print "<pre>Bye!\n";
  print Dumper($info);
}

sub try {
  my $request = $_[0];
  my $this = $_[1];
  if (ref $this) {
    return try($request, $this->{yes($request,$this->{Question}) ? 'Yes' : 'No' });
  }
  if (yes($request,"Is it a $this")) {
    $request->print("I got it!\n");
    return 1;
  };
  print "no!?  What was it then? ";
  chomp(my $new = stdin());
  print "And a question that distinguishes a $this from a $new would be? ";
  chomp(my $question = stdin());
  my $yes = yes("And for a $new, the answer would be...");
  $_[1] = {
           Question => $question,
           Yes => $yes ? $new : $this,
           No => $yes ? $this : $new,
          };
  return 0;
}

sub yes {
  print "@_ (yes/no)?";
  stdin() =~ /^y/i;
}

sub stdin {
  print qq{
    <form method=POST>
      <input id=in name=in type=text>
      <script>document.getElementById('in').focus();</script>
    </form>
  };
  my $params = $server->get_request->params;
  my $in = $params->{in};
  return $in;
}


1;

