#!/usr/bin/perl

use strict;
use lib '../lib';
use Continuity;

my @messages;
my $got_message;

my $server = Continuity->new(
  port => 16001,
  path_session => 1,
  staticp => sub {
    $_[0]->url->path =~ m/\.(jpg|gif|png|css|ico|js)$/
  },   
);

$server->loop;

sub pushstream {
  my ($req) = @_;
  # Set up watch event
  my $w = Coro::Event->var(var => \$got_message, poll => 'w');
  while(1) {
    print STDERR "**** Waiting for message ****\n";
    $w->next;
    print STDERR "**** GOT MESSAGE, SENDING ****\n";
    my $log = join "<br>", @messages;
    $req->print($log);
    $req->next;
  }
}

sub main {
  my ($req) = @_;
  $req->next;

  if($req->request->url->path =~ /pushstream/) {
    pushstream($req);
  }

  print STDERR "Path: '" . $req->request->url->path . "'\n";

  # We only send them the main HTML one time. Optimistic, eh?
  if($req->request->url->path eq '/') {
    while(1) {
      $req->print(qq{
        <html>
          <head>
            <title>Chat!</title>
            <script src="chat-ajax-push.js" type="text/javascript">></script>
          </head>
          <body>
            <form id=f>
            <input type=text id=username name=usernamename size=10>
            <input type=text id=message name=message size=50>
            <input type=submit name="sendbutton" value="Send" id="sendbutton">
            <span id=status></span>
            </form>
            <br>
            <div id=log>-- no messages yet --</div>
          </body>
        </html>
      });
      $req->next;
    }
  }

  while(1) {
    $req->next;
    $got_message = 1;
    my $msg = $req->param('message');
    my $name = $req->param('username');
    if($msg) {
      unshift @messages, "$name: $msg";
      pop @messages if $#messages > 15;
    }
    $req->print("Got it!");
  }
}

