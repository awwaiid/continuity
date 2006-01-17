
package Continuity::Server;

use strict;
use HTTP::Status; # to grab static response codes. Probably shouldn't be here

=head1 NAME

Continuity::Server - A continuation server based on Coro::Cont

=head1 DESCRIPTION

This is the central module for Continuity.

=head1 METHODS

=over

=item $server = new Continuity::Server(...)

Create a new continuation server

=cut

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  # Default docroot
  $self->{docroot} = '.';
  $self = {%$self, @_};
  bless $self, $class;

  # Set up the default mapper
  if(!$self->{mapper}) {
    eval { use Continuity::Mapper };
    $self->{mapper} = new Continuity::Mapper(
      debug => $self->{debug},
      new_cont_sub => $self->{new_cont_sub},
    ); # default mapper
  }

  # Set up the default adaptor
  # The default actually has its very own HTTP::Daemon running
  if(!$self->{adaptor}) {
    eval { use Continuity::Adapt::HttpDaemon };
    $self->{adaptor} = new Continuity::Adapt::HttpDaemon(
      debug => $self->{debug},
      port => $self->{port},
      docroot => $self->{docroot},
    );
  }

  return $self;
}

sub debug {
  my ($self, $level, $msg) = @_;
  if($level >= $self->{debug}) {
    print STDERR "$msg\n";
  }
}


# Actually execute the continuation. The only reason this is separate is so
# that it is easily overridable by inheriting classes who want to do something
# funky
sub execCont {
  my ($self, $continuation, $r, $c) = @_;
  eval { $continuation->($r, $c) };
}


=item $server->loop()

Loop, returning a new connection and request

=cut


sub loop {

  my ($self) = @_;
  my ($c, $r);
  
  while(($c, $r) = $self->{adaptor}->get_request()) {
    if($r->method eq 'GET' || $r->method eq 'POST') {

      # Send the basic headers all the time
      $c->send_basic_header();

      # We need some way to decide if we should send static or dynamic
      # content.
      if(!$self->{app_path} || $r->url->path eq $self->{app_path}) {
        $self->debug(3, "Calling map... ");
        my $continuation = $self->{mapper}->map($r, $c);
        $self->debug(3, "done mapping.");
        $self->execCont($continuation, $r, $c);
        $self->debug(1, "Error: $@") if $@; # Theoretically this will print errors??
      } else {
        $self->debug(3, "Sending static content... ");
        $self->{adaptor}->sendStatic($r, $c);
        $self->debug(3, "done sending static content.");
      }
    } else {
      $c->send_error(RC_NOT_FOUND)
    }

    $c->close;
    undef($c);
  }
}

=back

=head1 SEE ALSO

L<Continuity>

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org>
  http://thelackthereof.org/

=head1 COPYRIGHT

  Copyright (c) 2004-2006 Brock Wilcox <awwaiid@thelackthereof.org>. All rights
  reserved.  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut

1;

