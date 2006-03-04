#!/usr/bin/perl

use lib '..';
use Continuity::Server::Simple;
$server = new Continuity::Server::Simple;
#$server->ignore_path('/siteicon.ico');
$server->loop();

sub main {
  # must do a substr to chop the leading '/'
  $name = substr($server->get_request->url->path,1) || 'World';
  print "Hello, $name!";
  $name = substr($server->get_request->url->path,1) || 'World';
  print "Hello to you too, $name!";
}

