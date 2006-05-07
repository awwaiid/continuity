package Continuity;

our $VERSION = '0.5';

=head1 NAME

Continuity - Abstract away statelessness of HTTP using continuations for stateful Web applications

=head1 SYNOPSIS

  use Continuity;
  $server = new Continuity::Server::Simple;
  Event::loop;

  sub main {
    # must do a substr to chop the leading '/'
    $name = substr($server->get_request->url->path,1) || 'World';
    print "Hello, $name!";
    $name = substr($server->get_request->url->path,1) || 'World';
    print "Hello to you too, $name!";
  }

=head1 DESCRIPTION

Continuity seeks to be a library (not a framework) to simplify web
applications.
At the core is a continuation server, which inverts control back
to the programmer. 
Rather than exiting and waiting for the next request, applications call a method which
(eventually) returns the next request.
Corotines make HTTP Web appear stateful.
This is ALPHA software, and feedback/code is welcomed.
See the Wiki in the references below for things the authors are unhappy with.

=head1 METHODS

=cut

use strict;
use warnings; # XXX -- while in devolopment

use IO::Handle;
use Coro;
use Coro::Cont;
use HTTP::Status; # to grab static response codes. Probably shouldn't be here

=head2 C<< $server = Continuity::Server->new(...) >>

Create a new continuation server.
The program should run C<Event::loop> 

=cut

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
  my $self = { 
    docroot => '.',   # default docroot
    mapper => undef,
    adapter => undef,
    debug => 4, # XXX
    request => undef, # set by get_request and its ilk
    params => [ ],    # cached decoded params
    @_,  
  };

  bless $self, $class;

STDERR->print(__FILE__, ' ', __LINE__, "\n");

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

STDERR->print(__FILE__, ' ', __LINE__, "\n");
  # Set up the default adaptor.
  # The adapater plugs the system into a server (probably a Web server)
  # The default has its very own HTTP::Daemon running.
  if(!$self->{adaptor}) {
    require Continuity::Adapt::HttpDaemon;
    $self->{adaptor} = Continuity::Adapt::HttpDaemon->new(
      docroot => $self->{docroot},
      server => $self,
    );
  } elsif(! ref $self->{adaptor}) {
    die "Not a ref, $self->{adaptor}\n";
  }

STDERR->print(__FILE__, ' ', __LINE__, "\n");
  async {
STDERR->print(__FILE__, ' ', __LINE__, "\n");
    while((my $c, my $r) = $self->{adaptor}->get_request()) {
STDERR->print(__FILE__, ' ', __LINE__, "\n");
      unless($r->method eq 'GET' || $r->method eq 'POST') {
        #$c->send_error(RC_NOT_FOUND)
        #print $c "ERROR\r\n\r\n";
      }
  
      # Send the basic headers all the time
      if($c->can('send_basic_header')) {
        $c->send_basic_header();
      } else {
STDERR->print(__FILE__, ' ', __LINE__, " -- don't have the gumption to send basic headers\n");
        #print $c "Date: ",time2str(time),"\n";
        #print $c "Server: Dude\n";
      }
  
      # We need some way to decide if we should send static or dynamic
      # content.
      # To save users from having to re-implement (likely incorrecty)
      # basic security checks like .. abuse in GET paths, we should provide
      # a default implementation -- preferably one already on CPAN.
      # Here's a way: ask the mapper.
STDERR->print(__FILE__, ' ', __LINE__, "\n");
      if(!$self->{app_path} || $r->url->path =~ /$self->{app_path}/) {
STDERR->print(__FILE__, ' ', __LINE__, "\n");
        $self->debug(3, "Calling map... ");
STDERR->print(__FILE__, ' ', __LINE__, "\n");
        my $continuation = $self->{mapper}->map($r, $c);
STDERR->print(__FILE__, ' ', __LINE__, "\n");
        $self->debug(3, "done mapping.");
        # $continuation->($r, $c); # or $self->debug(1, "Error: $@");
        $self->exec_cont($continuation, $r, $c);
STDERR->print(__FILE__, ' ', __LINE__, "\n");
      } else {
        $self->debug(3, "Sending static content... ");
        $self->{adaptor}->send_static($r, $c);
        $self->debug(3, "done sending static content.");
      }

      $c->close;
      undef($c);

    }
  
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


=head2 C<< $server->exec_cont($subref, $request, $conn) >>

Override in subclasses for more specific behavior.
This default implementation sends HTTP headers, selects C<$conn> as the
default filehandle for output, and invokes C<$subref> (which is presumabily
a continuation) with C<$request> and C<$conn> as arguments.

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

STDERR->print(__FILE__, ' ', __LINE__, "\n");
  $cont->($request);
STDERR->print(__FILE__, ' ', __LINE__, "\n");

  select $prev_select;
}

=head2 C<< $server->get_request >>

Get a request from the server and returns an L<HTTP::Request> object. 

XXX todo: need another method that does the same thing but returns a CGI object created from the request.

All this really does (right now) is yield the running continuation, returning control to the looping 
L<Continuity::Server> process.

XXX ooooooh... this is slowly coming back to me... I wanted the user process to be able to itself
use continuations. For that to happen, it would have to be able to wait for Request objects 
without using yield.
How to implement that?
Have the coroutine accept request objects through a queue, where the queue is
passed in on coroutine creation or via a global variable.
A central coroutine process does the actual accepting and then simply pushes the request through
the correct queue.
Then this here get_request() would just wait on that queue.

=cut
 
sub get_request {
    my ($self, $retval) = @_;
    yield $retval;
    my ($request) = @_;
    $self->{request} = $request;
    $self->{params} = [ $self->request_to_params($request) ];
    return $request;
}

=head2 C<< param('name') >> or C<< param() >>

Works kind of like the L<CGI> counterpart -- given a name, it returns the one or more parameters with that name,
and without a name, returns a list of parameter names.

There's a request_to_params(), but that's an internal thing.

XXX todo: understands GET parameters and POST in application/x-www-form-urlencoded format, but not
POST data in multipart/form-data format.
Use the AsCGI thing if you actually really need that (it's used for file uploads).

=cut

sub param {
    my $self = shift; (ref $self and $self->isa('CGI')) or confess $self;
    my @params = @{ $self->{params} || [ ] };
    if(@_) {
        my $param = shift;
        my @values;
        for(my $i = 0; $i < @params; $i += 2) {
            push @values, $params[$i+1] if $params[$i] eq $param;
        }
        return unless @values;
        return wantarray ? @values : $values[0];
    } else {
        my @values;
        for(my $i = 0; $i < @params; $i += 2) {
            push @values, $params[$i+1];
        }
        return @values;
    }
} 

sub request_to_params {
    my $self = shift;
    my $req = shift;
    my $in = $req->uri; 
    $in .= '&' . $req->content if $req->content;
    my @params;
    for(split/[&]/, $in) { tr/+/ /; s{%(..)}{pack('c',hex($1))}ge; s{(.*?)=(.*)}{ push @params, $1, $2; STDERR->print("debug: setting $1 to $2\n"); ''; }e; };
    wantarray ? @params : \@params;
}

=head1 SEE ALSO

Website/Wiki: L<http://continuity.tlt42.org/>

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org>
  http://thelackthereof.org/

=head1 COPYRIGHT

  Copyright (c) 2004-2006 Brock Wilcox <awwaiid@thelackthereof.org>. All rights
  reserved.  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut

1;

