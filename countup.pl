
use strict;
use CServe;

sub main {
  my ($request) = @_;
  my $count = 0;
  while(1) {
    $count++;
    my $out = "Count: $count";
    $request = yield $out;
  }
}

# Serve this program
CServe::serve(\&main);

