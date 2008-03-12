#!/usr/bin/env perl

use strict;
use Test::More;

eval "use Test::WWW::Mechanize";
if($@) {
  plan skip_all => 'Test::WWW::Mechanize not installed';
} else {
  plan tests => 10;
}

my $server_pid = open my $app, '-|', 'perl eg/cookies.pl 2>&1'
  or die "Error starting server: $!\n";
$app->autoflush;

my $server = <$app>;
chomp $server;
$server =~ s/^Please contact me at: //;

my $mech = Test::WWW::Mechanize->new;

$mech->get_ok( $server );
$mech->content_contains("Setting 'continuity-cookie-demo' to 10");

$mech->get_ok( $server );
$mech->content_contains("Got 'continuity-cookie-demo' == 10");

$mech->get_ok( $server );
$mech->content_contains("... still got 'continuity-cookie-demo' == 10");
$mech->content_contains("Setting 'continuity-cookie-demo' to 20");

$mech->get_ok( $server );
$mech->content_contains("Got 'continuity-cookie-demo' == 20");
$mech->content_contains("All done with cookie demo!");

kill 1, $server_pid;

