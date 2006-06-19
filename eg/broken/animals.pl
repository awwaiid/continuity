#!/usr/bin/perl -w

use strict;
use lib '../lib';
use Continuity::Server::Simple;
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

my $server = Continuity::Server::Simple->new(
    port => 8081,
    new_cont_sub => \&main,
    app_path => '/app',
    debug => 3,
);

$server->loop;

sub main {
  # Ignore the first input, it just indicates that they are viewing the page
  $server->get_request;
  {
    try($info);
    redo if (yes("play again?"));
  }
  print "<pre>Bye!\n";
  print Dumper($info);
}

sub try {
  my $this = $_[0];
  if (ref $this) {
    return try($this->{yes($this->{Question}) ? 'Yes' : 'No' });
  }
  if (yes("Is it a $this")) {
    print "I got it!\n";
    return 1;
  };
  print "no!?  What was it then? ";
  chomp(my $new = stdin());
  print "And a question that distinguishes a $this from a $new would be? ";
  chomp(my $question = stdin());
  my $yes = yes("And for a $new, the answer would be...");
  $_[0] = {
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

