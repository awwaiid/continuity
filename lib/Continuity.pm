package Continuity;

our $VERSION = '0.95';

=head1 NAME

Continuity - Abstract away statelessness of HTTP using continuations, for stateful Web applications

=head1 SYNOPSIS

  #!/usr/bin/perl

  use strict;
  use Continuity;

  my $server = new Continuity;
  $server->loop;

  sub main {
    my $request = shift;
    $request->print("Your name: <form><input type=text name=name></form>");
    $request->next; # this waits for the form to be submitted!
    my $name = $request->param('name');
    $request->print("Hello $name!");
  }

=head1 DESCRIPTION

This is BETA software, and feedback/code is welcomed.

Continuity is a library to simplify web applications. Each session is written
and runs as a persistant application, and is able to request additional input
at any time without exiting. This is significantly different from the
traditional CGI model of web applications in which a program is restarted for
each new request.

The program is passed a $request variable which holds the request (including
any form data) sent from the browser. In concept, this is a lot like a C<$cgi>
object from CGI.pm with one very very significant difference. At any point in
the code you can call $request->next. Your program will then suspend, waiting
for the next request in the session. Since the program doesn't actually halt,
all state is preserved, including lexicals -- getting input from the browser is
then similar to doing C<$line=E<lt>E<gt>> in a command-line application.

=head1 GETTING STARTED

First, check out the small demo applications in the eg/ directory of the
distribution. Sample code there ranges from simple counters to more complex
multi-user ajax applications.

Declare all your globals, then declare and create your server. Parameters to
the server will determine how sessions are tracked, what ports it listens on,
what will be served as static content, and things of that nature. Then call the
C<loop> method of the server, which will get things going (and never exits).

  use Continuity;
  my $server = Continuity->new( port => 8080 );
  $server->loop;

Continuity must have a starting point for creating a new instance of your
application. The default is to C<\&::main>, which is passed the C<$request>
handle. See the L<Continuity::Request> documentation for details on the methods
available from the C<$request> object beyond this introduction.

  sub main {
    my $request = shift;
    # ...
  }

Outputting to the client (that is, sending text to the browser) is done by
calling the C<$request-E<gt>print(...)> method, rather than the plain C<print> used
in CGI.pm applications.

  $request->print("Hello, guvne'<br>");
  $request->print("'ow ya been?");

HTTP query parameters (both GET and POST) are also gotten through the
C<$request> handle, by calling C<$p = $request-E<gt>param('p')>, like in C<CGI>.

  # If they go to http://webapp/?x=7
  my $input = $request->param('x');
  # now $input is 7

Once you have output your HTML, call C<$request-E<gt>next> to wait for the next
response from the client browser. While waiting other sessions will handle
other requests, allowing the single process to handle many simultaneous
sessions.

  $request->print("Name: <form><input type=text name=n></form>");
  $request->next;                   # <-- this is where we suspend execution
  my $name = $request->param('n');  # <-- start here once they submit

Anything declared lexically (using my) inside of C<main> is private to the
session, and anything you make global is available to all sessions. When
C<main> returns the session is terminated, so that another request from the
same client will get a new session. Only one continuation is ever executing at
a given time, so there is no immediate need to worry about locking shared
global variables when modifying them.

=head1 ADVANCED USAGE

Merely using the above code can completely change the way you think about web
application infrastructure. But why stop there? Here are a few more things to
ponder.

Since Continuity is based on L<Coro>, we also get to use L<Coro::Event>. This
means that you can set timers to wake a continuation up after a while, or you
can have inner-continuation signaling by watch-events on shared variables.

For AJAX applications, we've found it handy to give each user multiple
sessions. In the chat-ajax-push demo each user gets a session for sending
messages, and a session for receiving them. The receiving session uses a
long-running request (aka COMET) and watches the globally shared chat message
log. When a new message is put into the log, it pushes to all of the ajax
listeners.

Don't forget about those pretty little lexicals you have at your disposal.
Taking a hint from the Seaside folks, instead of regular links you could have
callbacks that trigger a anonymous subs. Your code could easily look like:

  my $x;
  $link1 = gen_link('This is a link to stuff', sub { $x = 7  });
  $link2 = gen_link('This is another link',    sub { $x = 42 });
  $request->print($link1, $link2);
  $request->next;
  process_links($request);
  # Now use $x

To scale a Continuity-based application beyond a single process you need to
investigate the keywords "session affinity". The Seaside folks have a few
articles on various experiments they've done for scaling, see the wiki for
links and ideas. Note, however, that premature optimization is evil. We
shouldn't even be talking about this.

=head1 EXTENDING AND CUSTOMIZING

This library is designed to be extensible but have good defaults. There are two
important components which you can extend or replace.

The Adaptor, such as the default L<Continuity::Adapt::HttpDaemon>, actually
makes the HTTP connections with the client web broswer. If you want to use
FastCGI or even a non-HTTP protocol, then you will use or create an adaptor.

The Mapper, such as the default L<Continuity::Mapper>, identifies incoming
requests from The Adaptor and maps them to instances of your program. In other
words, Mappers keep track of sessions, figuring out which requests belong to
which session. The default mapper can identify sessions based on any
combination of cookie, ip address, and URL path. Override The Mapper to create
alternative session identification and management.

=head1 METHODS

The main instance of a continuity server really only has two methods, C<new>
and C<loop>. These are used at the top of your program to do setup and start
the server. Please look at L<Continuity::Request> for documentation on the
C<$request> object that is passed to each session in your application.

=cut

use strict;
use warnings; # XXX -- while in devolopment

use IO::Handle;
use Coro;
use Coro::Event;
use HTTP::Status; # to grab static response codes. Probably shouldn't be here
use Continuity::RequestHolder;

our $_debug_level;
sub debug_level :lvalue { $_debug_level }         # Debug level (integer)

=head2 $server = Continuity->new(...)

The C<Continuity> object wires together an adapter and a mapper.
Creating the C<Continuity> object gives you the defaults wired together,
or if user-supplied instances are provided, it wires those together.

Arguments:

=over 4

=item * C<callback> -- coderef of the main application to run persistantly for each unique visitor -- defaults to C<\&::main>

=item * C<adapter> -- defaults to an instance of C<Continuity::Adapt::HttpDaemon>

=item * C<mapper> -- defaults to an instance of C<Continuity::Mapper>

=item * C<docroot> -- defaults to C<.>

=item * C<staticp> -- defaults to C<< sub { $_[0]->url =~ m/\.(jpg|jpeg|gif|png|css|ico|js)$/ } >>, used to indicate whether any request is for static content

=item * C<debug_level> -- defaults to C<4> at the moment ;)

=back

Arguments passed to the default adaptor:

=over 4

=item * C<port> -- the port on which to listen

=item * C<no_content_type> -- defaults to 0, set to 1 to disable the C<Content-Type: text/html> header and similar headers

=back

Arguments passed to the default mapper:

=over 4

=item * C<cookie_session> -- set to name of cookie or undef for no cookies (defaults to 'cid')

=item * C<query_session> -- set to the name of a query variable for session tracking (defaults to undef)

=item * C<assign_session_id> -- coderef of routine to custom generate session id numbers (defaults to a simple random string generator)

=item * C<ip_session> -- set to true to enable ip-addresses for session tracking (defaults to false)

=item * C<path_session> -- set to true to use URL path for session tracking (defaults to false)

=item * C<implicit_first_next> -- set to false to get an empty first request to the main callback (defaults to true)

=back

=cut

sub new {

  my $this = shift;
  my $class = ref($this) || $this;

  my $self = bless { 
    docroot => '.',   # default docroot
    mapper => undef,
    adapter => undef,
    debug_level => 4, # XXX
    reload => 1, # XXX
    callback => (exists &::main ? \&::main : undef),
    staticp => sub { $_[0]->url =~ m/\.(jpg|jpeg|gif|png|css|ico|js)$/ },
    no_content_type => 0,
    reap_after => undef,
    @_,  
  }, $class;

  if($self->{reload}) {
    eval "use Module::Reload";
    $self->{reload} = 0 if $@;
    $Module::Reload::Debug = 1 if $self->debug_level;
  }

  # Set up the default adaptor.
  # The adapater plugs the system into a server (probably a Web server)
  # The default has its very own HTTP::Daemon running.
  if(!$self->{adaptor}) {
    require Continuity::Adapt::HttpDaemon;
    $self->{adaptor} = Continuity::Adapt::HttpDaemon->new(
      docroot => $self->{docroot},
      server => $self,
      debug_level => $self->debug_level,
      no_content_type => $self->{no_content_type},
      $self->{port} ? (LocalPort => $self->{port}) : (),
    );
  } elsif(! ref $self->{adaptor}) {
    die "Not a ref, $self->{adaptor}\n";
  }

  # Set up the default mapper.
  # The mapper associates execution contexts (continuations) with requests 
  # according to some criteria. The default version uses a combination of
  # client IP address and the path in the request.

  if(!$self->{mapper}) {

    require Continuity::Mapper;

    my %optional;
    $optional{LocalPort} = $self->{port} if defined $self->{port};
    for(qw/ip_session path_session query_session cookie_session assign_session_id 
           implicit_first_next/) {
        # be careful to pass 0 too if the user specified 0 to turn it off
        $optional{$_} = $self->{$_} if defined $self->{$_}; 
    }

    $self->{mapper} = Continuity::Mapper->new(
      debug_level => $self->debug_level,
      callback => $self->{callback},
      server => $self,
      %optional,
    );

  } else {

    # Make sure that the provided mapper knows who we are
    $self->{mapper}->{server} = $self;

  }

  async {
    while(1) {
      my $r = $self->adaptor->get_request;
      if($self->{reload}) {
        Module::Reload->check;
      }

      unless($r->method eq 'GET' or $r->method eq 'POST') {
         $r->send_error(RC_BAD_REQUEST);
         $r->print("ERROR -- GET and POST only for now\r\n\r\n");
         $r->close;
         next;
      }
  
      # We need some way to decide if we should send static or dynamic
      # content.
      # To save users from having to re-implement (likely incorrecty)
      # basic security checks like .. abuse in GET paths, we should provide
      # a default implementation -- preferably one already on CPAN.
      # Here's a way: ask the mapper.
  
      if($self->{staticp}->($r)) {
          $self->debug(3, "Sending static content... ");
          $self->{adaptor}->send_static($r);
          $self->debug(3, "done sending static content.");
          next;
      }

      # Right now, map takes one of our Continuity::RequestHolder objects (with conn and request set) and sets queue

      # This actually finds the thing that wants it, and gives it to it
      # (executes the continuation)
      $self->debug(3, "Calling map... ");
      $self->mapper->map($r);
      $self->debug(3, "done mapping.");

    }
  
    STDERR->print("Done processing request, waiting for next\n");
    
  };

  return $self;
}

=head2 $server->loop()

Calls Coro::Event::loop and sets up session reaping. This never returns!

=cut

no warnings 'redefine';

sub loop {
  my ($self) = @_;

  # Coro::Event is insane and wants us to have at least one event... or something
  async {
     my $timeout = 300;  
     $timeout = $self->{reap_after} if $self->{reap_after} and $self->{reap_after} < $timeout;
     my $timer = Coro::Event->timer(interval => $timeout, );
     while ($timer->next) {
        $self->debug(3, "debug: loop calling reap");
        $self->mapper->reap($self->{reap_after}) if $self->{reap_after};
     }
  };

  # XXX passing $self is completely invalid. loop is supposed to take a timeout
  # as the parameter, but by passing self it creates a semi-valid timeout.
  # Without this, with the current Coro and Event, it doesn't work.
  cede;
  Coro::Event::loop();
}

sub debug {
  my ($self, $level, $msg) = @_;
  if($self->debug_level and $level >= $self->debug_level) {
    print STDERR "$msg\n";
  }
}

sub adaptor :lvalue { $_[0]->{adaptor} }

sub mapper :lvalue { $_[0]->{mapper} }


=head1 SEE ALSO

See the Wiki for development information, more waxing philosophic, and links to
similar technologies such as L<http://seaside.st/>.

Website/Wiki: L<http://continuity.tlt42.org/>

L<Continuity::Request>, L<Continuity::Mapper>,
L<Continuity::Adapt::HttpDaemon>, L<Coro>

=head1 AUTHOR

  Brock Wilcox <awwaiid@thelackthereof.org> - http://thelackthereof.org/
  Scott Walters <scott@slowass.net> - http://slowass.net/
  Special thanks to Marc Lehmann for creating (and maintaining) Coro

=head1 COPYRIGHT

  Copyright (c) 2004-2007 Brock Wilcox <awwaiid@thelackthereof.org>. All
  rights reserved.  This program is free software; you can redistribute it
  and/or modify it under the same terms as Perl itself.

=cut

1;

