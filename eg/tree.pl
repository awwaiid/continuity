#!/usr/bin/perl

use lib '../lib';
use strict;
use Coro::Cont;

sub my_yield {
  my ($self) = @_;
  yield;
  my ($ref) = @_;
  if($ref) {
    my $dup = csub { $ref->(@_) };
    yield $dup;
  }
  return;
}

# Take a sub ref and give back a continuation. Just a shortcut
sub mkcont {
  my ($func) = @_;
  my $cont = csub { $func->(@_) };
  return $cont;
}

sub mkContMaker {
  my ($func) = @_;
  my $mkNewCont = sub {
    mkcont($func)
  };
  return $mkNewCont;
}

sub sing {
  my ($num) = @_;
  my $song = 'ants';
  print "The $song go marching $num by $num... harrah, harrah...\n";
}

sub main {
  my $i = 0;
  #for(0..4) {
  while(1) {
    $i++;
    print "$i\n";
    sing($i);
    my_yield;
  }
}

my $contMaker = mkContMaker(\&main);

my $c1 = $contMaker->();

print "Running c1 for 3 iterations\n";
$c1->();
$c1->();
$c1->();

print "Creating branch c2\n";
my $c2 = $c1->($c1);

print "Running c1 for 3 iterations\n";
$c1->();
$c1->();
$c1->();

print "Running c2 for 3 iterations\n";
$c2->();
$c2->();
$c2->();

