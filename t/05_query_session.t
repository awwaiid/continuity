#!/usr/bin/env perl

use strict;
use Test::More;

eval "use Test::WWW::Mechanize";
if($@) {
  plan skip_all => 'Test::WWW::Mechanize not installed';
} else {
  plan tests => 3;
}

my $server_pid = open my $app, '-|', 'perl eg/query_session.pl 2>&1'
  or die "Error starting server: $!\n";
$app->autoflush;

my $server = <$app>;
chomp $server;
$server =~ s/^Please contact me at: //;

my $mech = Test::WWW::Mechanize->new;

$mech->get_ok( $server );
$mech->follow_link_ok({ text => 'Click here to continue' }, 'Link-based (GET) query');
$mech->click_button( value => 'Click here to continue' );
$mech->follow_link_ok({ text => 'Click here to get a new one' }, 'Begin again');

kill 1, $server_pid;

