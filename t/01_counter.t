#!/usr/bin/env perl

use strict;
use Test::More;
use IO::Handle;

eval "use Test::WWW::Mechanize";
if($@) {
  plan skip_all => 'Test::WWW::Mechanize not installed';
} else {
  plan tests => 14;
}

my $server_pid = open my $app, '-|', 'perl eg/counter.pl 2>&1'
  or die "Error starting server: $!\n";
$app->autoflush;

my $server = <$app>;
chomp $server;
$server =~ s/^Please contact me at: //;

my $mech = Test::WWW::Mechanize->new;

$mech->get_ok( $server );
$mech->content_contains('Count: 0', 'Initial count');

$mech->follow_link_ok({ text => '++' }, 'Click increment link');
$mech->content_contains('Count: 1', 'Updated count');

$mech->follow_link_ok({ text => '++' }, 'Click increment link');
$mech->content_contains('Count: 2', 'Updated count');

$mech->follow_link_ok({ text => '--' }, 'Click decrement link');
$mech->content_contains('Count: 1', 'Updated count');

$mech->follow_link_ok({ text => '--' }, 'Click decrement link');
$mech->content_contains('Count: 0', 'Updated count');

$mech->follow_link_ok({ text => '--' }, 'Click decrement link');
$mech->content_contains('GO NEGATIVE', 'Go Negative Check');
$mech->follow_link_ok({ text => 'Yes' }, 'Lets go negative!');
$mech->content_contains('Count: -1', 'Updated count');

kill 1, $server_pid;

