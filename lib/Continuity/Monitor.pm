
package Continuity::Monitor;

use strict;
use Continuity;
use Continuity::Inspector;
use Coro;

sub new {
  my ($class, @ops) = @_;
  my $self = {
    port => 8081,
    @ops
  };
  bless $self, $class;

  $self->start_server;

  return $self;
}

sub start_server {
  my ($self) = @_;
  my $server = Continuity->new(
      port => $self->{port},
      cookie_session => 'monitor_sid',
      callback => sub { $self->main(@_) },
  );
}

sub main {
  my ($self, $request) = @_;
  $self->{request} = $request;
  my $server = $self->{server};
  while(1) {
    my $sessions = $server->{mapper}->{sessions};
    my $session_count = scalar keys %$sessions;
    my @sess = sort keys %$sessions;
    @sess = map { qq{<li><a href="?inspect_sess=$_">$_</a></li>\n} } @sess;
    $request->print("$session_count sessions:<br><ul>@sess</ul>");
    $request->next;
    my $sess = $request->param('inspect_sess');
    if($sess) {
      $self->inspect_session($sessions->{$sess});
    }

=for comment

    my $sess;
    my $inspector = Continuity::Inspector->new( callback => sub {
      use PadWalker 'peek_my';
      for my $i (1..100) { 
        my $vars = peek_my($i) or last;
        use Data::Dumper;
        $request->print("<pre>\n\n" . Dumper($vars) . "</pre>");
        next unless exists $vars->{'$number'};
        $request->print("$sess: secret number: ", ${ $vars->{'$number'} }, "<br>\n");
        last;
      }
    });
    foreach $sess (keys %$sessions) {
      print STDERR "Looking at $sess...\n";
      # next unless $sess =~ /^\.\./;
      next if $sess eq $request->session_id;  # don't try to peek on ourself.  that would be bad.
      # next if $sess =~ /peek/;  # don't try to peek on ourself.  that would be bad.
      $inspector->inspect( $sessions->{$sess} );
    }

=cut

  }
}

sub inspect_session {
  my ($self, $session) = @_;
  my $request = $self->{request};
  my $inspector = Continuity::Inspector->new( callback => sub {
    use PadWalker 'peek_my';
    use Data::Dumper;
    $Data::Dumper::Sortkeys = 1;
    $Data::Dumper::Terse = 1;
    for my $i (1..100) { 
      my $vars = eval { peek_my($i) } or last;
      my ($package, $filename, $line, $subroutine) = caller($i-1);
      my ($package2, $filename2, $line2, $subroutine2) = caller($i);
      $Data::Dumper::Maxdepth = 2;
      next if $package =~ /^(Continuity|Coro)/;
      next if $subroutine2 =~ /^(Continuity|Coro)::/;
      $request->print("<pre>\n\nLevel "
                    . $i
                    . "\n$package, $filename:$line\n$subroutine2\n"
                    . Dumper($vars)
                    . "</pre>");
      #next unless exists $vars->{'$number'};
      #$request->print("secret number: ", ${ $vars->{'$number'} }, "<br>\n");
      #last;
    }
  });
  $inspector->inspect( $session );
}


1;

