#!/usr/bin/perl -w

use strict;
use lib '../lib';
use Continuity;
use Data::Dumper;
no warnings;

# This is the A MODIFIED VERSION written by awwaiid.
# The original version was written by Merlyn,
# http://www.perlmonks.org/?node_id=200391

# We cheat -- we don't have to pass $request around because all of the
# subroutines are in the scope of main (and thus share the originally passed
# $request variable).

my $info = "dog";

my $server = Continuity->new;
$server->loop;

sub main {
  my $request = shift;

  {
    try($info);
    redo if (yes("play again?"));
  }
  printout("<pre>Bye! Here's my DB");
  printout(Dumper($info));

  sub printout {
    $request->print(@_);
  }

  sub stdin {
    printout qq{
      <form method=POST>
        <input id=in name=in type=text>
        <script>document.getElementById('in').focus();</script>
      </form>
    };
    $request->next;
    my $in = $request->param('in');
    return $in;
  }

  sub try {
    my $this = $_[0];
    if (ref $this) {
      return try($this->{yes($this->{Question}) ? 'Yes' : 'No' });
    }
    if (yes("Is it a $this")) {
      printout("I got it!\n");
      return 1;
    };
    printout("no!?  What was it then? ");
    chomp(my $new = stdin());
    printout("And a question that distinguishes a $this from a $new would be? ");
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
    printout "@_ (yes/no)?";
    stdin() =~ /^y/i;
  }

}

1;

