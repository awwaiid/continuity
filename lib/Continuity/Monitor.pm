package Continuity::Monitor;

use strict;
use Continuity;
use Continuity::Inspector;
use PadWalker 'peek_my';
use Data::Dumper;

=head1 NAME

Continuity::Monitor - monitor and inspect a Continuity server

=head1 SYNOPSIS

  #!/usr/bin/perl

  use strict;
  use Continuity;
  use Continuity::Monitor;

  my $server = new Continuity( port => 8080 );
  my $monitor = Continuity::Monitor->new( server => $server, port => 8081 );
  $server->loop;

=head1 DESCRIPTION

This is an application to monitor and inspect your running application. It has
its own web interface on a separate port. It is very rough.

The monitor does several things. First, this is a monitoring tool for working
with the sessions your server is running. You can view and kill each session.
Secondly it is an inspector for each session -- letting you see the current
state including variables. And third, it will let you actually change the
values of these sessions, or even run code in their context.

(well... it _will_ do all those things :) )

=head1 METHODS

=head2 $monitor = Continuity::Monitor->new( server => $server, ... )

This is just like Continuity->new, and takes all of the same parameters, except
that instead of running your code it is a self-contained application.

=cut

sub new {
  my ($class, @ops) = @_;
  my $self = {
    port => 8081, # override default port to avoid a conflict
    @ops
  };

  bless $self, $class;

  # We don't save the server... because we don't need it and because weird
  # things happen when we do :)
  Continuity->new(
      port => $self->{port},
      cookie_session => 'monitor_sid',
      callback => sub { $self->main(@_) },
  );

  return $self;
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
  }
}

sub inspect_session {
  my ($self, $session) = @_;
  my $request = $self->{request};
  my $inspector = Continuity::Inspector->new( callback => sub {
    $Data::Dumper::Sortkeys = 1;
    $Data::Dumper::Terse = 1;
    for my $i (1..100) { 
      my $vars = eval { peek_my($i) } or last;
      my ($package, $filename, $line, $subroutine) = caller($i-1);
      my ($package2, $filename2, $line2, $subroutine2) = caller($i);
      $Data::Dumper::Maxdepth = 2;
      # Skip over Continuity and Coro specific frames
      next if $package =~ /^(Continuity|Coro)/;
      next if $subroutine2 =~ /^(Continuity|Coro)::/;
      $request->print("<pre>\n\nLevel "
                    . $i
                    . "\n$package, $filename:$line\n$subroutine2\n"
                    . Dumper($vars)
                    . "</pre>");
    }
  });
  $inspector->inspect( $session );
}


1;

