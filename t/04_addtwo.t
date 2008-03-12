#!/usr/bin/env perl

use strict;
use Test::More;

eval "use Test::WWW::Mechanize";
if($@) {
  plan skip_all => 'Test::WWW::Mechanize not installed';
} else {
  plan tests => 4;
}

my $server_pid = open my $app, '-|', 'perl eg/addtwo.pl 2>&1'
  or die "Error starting server: $!\n";
$app->autoflush;

my $server = <$app>;
chomp $server;
$server =~ s/^Please contact me at: //;

my $mech = Test::WWW::Mechanize->new;

$mech->get_ok( $server );

my $num1 = int rand 1000;
my $num2 = int rand 1000;
my $sum  = $num1 + $num2;

$mech->content_contains("Enter first number");
$mech->field( num => $num1 );
$mech->submit;

$mech->content_contains("Enter second number");
$mech->field( num => $num2 );
$mech->submit;

$mech->content_contains("The sum of $num1 and $num2 is $sum!");

kill 1, $server_pid;

