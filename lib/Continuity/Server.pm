
package Continuity::Server;

use strict;
use warnings; # XXX -- while in devolopment

use IO::Handle;
use Coro;
use Coro::Cont;
use HTTP::Status; # to grab static response codes. Probably shouldn't be here

=head1 NAME

Continuity::Server - A continuation server based on Coro::Cont

=head1 DESCRIPTION

This is the central module for Continuity.

=head1 METHODS

=head2 $server = Continuity::Server->new(...)

Create a new continuation server

=cut

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
  my $self = { 
    docroot => '.',   # default docroot
    mapper => undef,
    adapter => undef,
    @_,  
  };

  bless $self, $class;

  # Set up the default mapper.
  # The mapper associates execution contexts (continuations) with requests 
  # according to some criteria.  The default version uses a combination of
  # client IP address and the path in the request.  
  if(!$self->{mapper}) {
    require Continuity::Mapper;
    $self->{mapper} = Continuity::Mapper->new(
      debug => $self->{debug},
      new_cont_sub => $self->{new_cont_sub},
      server => $self,
    );
  }

  # Set up the default adaptor.
  # The adapater plugs the system into a server (probably a Web server)
  # The default has its very own HTTP::Daemon running.
  if(!$self->{adaptor}) {
    require Continuity::Adapt::HttpDaemon;
    $self->{adaptor} = Continuity::Adapt::HttpDaemon->new(
      debug => $self->{debug},
      docroot => $self->{docroot},
      server => $self,
    );
  }

  if($self->{adaptor} && (!(ref $self->{adaptor}))) {
    die "Not a ref, $self->{adaptor}\n";
  }

  async { 
    while((my $c, my $r) = $self->{adaptor}->get_request()) {
      print STDERR "Got request\n";
      if($r->method eq 'GET' || $r->method eq 'POST') {
  
        # Send the basic headers all the time
        if($c->can('send_basic_header')) {
          $c->send_basic_header();
        } else {
          #print $c "Date: ",time2str(time),"\n";
          #print $c "Server: Dude\n";
        }
  
        # We need some way to decide if we should send static or dynamic
        # content.
        # To save users from having to re-implement (likely incorrecty)
        # basic security checks like .. abuse in GET paths, we should provide
        # a default implementation -- preferably one already on CPAN.
        if(!$self->{app_path} || $r->url->path =~ /$self->{app_path}/) {
          $self->debug(3, "Calling map... ");
          my $continuation = $self->{mapper}->map($r, $c);
          $self->debug(3, "done mapping.");
          # $continuation->($r, $c); # or $self->debug(1, "Error: $@");
          $self->exec_cont($continuation, $r, $c);
        } else {
          $self->debug(3, "Sending static content... ");
          $self->{adaptor}->send_static($r, $c);
          $self->debug(3, "done sending static content.");
        }
      } else {
        #$c->send_error(RC_NOT_FOUND)
        #print $c "ERROR\r\n\r\n";
      }
  
      $c->close;
      undef($c);
      STDERR->print("Done processing request, waiting for next\n");
    
  };

  return $self;

}

sub debug {
  my ($self, $level, $msg) = @_;
  if(defined $self->{debug} and $level >= $self->{debug}) {
    print STDERR "$msg\n";
  }
}


=head2 $server->exec_cont($subref, $request, $conn)

Override in subclasses for more specific behavior.
This default implementation sends HTTP headers, selects C<$conn> as the
default filehandle for output, and invokes C<$subref>, which is presumabily
a continuation, with C<$request> and C<$conn> as arguments.

=cut

sub exec_cont {

  my ($self, $cont, $request, $conn) = @_;

  my $prev_select = select $conn; # Should maybe do fancier trick than this

  if(!$self->{no_content_type}) {
    print "Cache-Control: private, no-store, no-cache\r\n";
    print "Pragma: no-cache\r\n";
    print "Expires: 0\r\n";
    print "Content-type: text/html\r\n\r\n";
  }

  $cont->($request);

  select $prev_select;
}

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

