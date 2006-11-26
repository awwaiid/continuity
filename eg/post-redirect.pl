#!/usr/bin/perl

use strict;
use lib '../lib';
use Continuity;

Continuity->new(port => 8081)->loop;

sub main {
  my ($request) = @_;
  $request->next;
  my $pageID;
  my $num = 0;
  my $msg = '';
  my %cache;
  my $count = 0;
  while(1) {
    my $next_pageID = sprintf "%x", int rand 0xffffffff;
    print STDERR "Displaying form. NextPID: $next_pageID\n";
    $request->print(qq{
      <html>
        <body>
          <h1>$msg</h1>
          <h2>You chose: $num ($pageID)</h2>
          <form method=POST action="/">
            <input type=hidden name="pageID" value="$next_pageID">
            Number: <input type=text name=num><br>
            <input type=submit name=submit value="Send">
          </form>
        </body>
      </html>
    });
    $msg = '';
    $request->{no_content_type} = 1;
    $request->next;
    $num = $request->param('num');
    $pageID = $request->param('pageID');
    print STDERR "Num: $num\tPageID: $pageID\n";
    if($cache{$pageID}) {
      print STDERR "Already been here...\n";
      if($cache{$pageID} == $count - 1) {
        $msg = "RELOAD detected ($cache{$pageID})!";
      } else {
        $msg = "BACK detected ($cache{$pageID})!";
      }
    } else {
      $cache{$pageID} = $count++;
    }
    print STDERR "Doing redirect after POST\n";
    $request->request->conn->send_redirect("/?pageID=$pageID",303);
    $request->{no_content_type} = 0;
    $request->next;
  }
}

