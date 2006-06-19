
package Continuity::Request::Wrapper;

=for comment

We've got three layers of abstraction here:

* Continuity::Request::Wrapper stands in front of Continuity::Request objects
* Continuity::Request objects stand in front of HTTP::Request objects
* An of course there's HTTP::Request

=cut

sub new {
    my $class = shift;
    my %args = @_;
    exists $args{queue} or die;
    # exists $args{request} or die;
    bless \%args, $class;
}

sub next {
    # called by the user's program from the context of their coroutine
    my $self = shift;
    $self->request and $self->request->conn and $self->request->conn->close;
    $self->request = $self->queue->get;
    $self;
}

sub param {
    my $self = shift;
    $self->request->param(@_);    
}

sub print {
    my $self = shift; 
    fileno $self->request->conn or return undef;
    Coro::Event->io( fd => $self->request->conn, poll => 'w', )->next->stop;
    for my $watcher (Event::all_running) { eval { $watcher->stop } }
    $self->request->conn->print(@_); 
}

sub request :lvalue { $_[0]->{request} }

sub queue :lvalue { $_[0]->{queue} }

sub AUTOLOAD {
    my $method = $AUTOLOAD; $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
    $self->request->request->can($method) ? $self->request->request->can($method)->($self->request->request, @_) : warn "Continuity::Request::AUTOLOAD: HTTP::Request method ``$method'' failed to exist for us";
}

#
#
#

package Continuity::Request;

use base 'HTTP::Request';

=for comment

This is what gets passed through a queue to coroutines when new requests for them come in.
It needs to encapsulate:

  The connection filehandle
  CGI parameters cache

=head2 C<< param('name') >> or C<< param() >>

Works kind of like the L<CGI> counterpart -- given a name, it returns the one or more parameters with that name,
and without a name, returns a list of parameter names.

XXX todo: understands GET parameters and POST in application/x-www-form-urlencoded format, but not
POST data in multipart/form-data format.
Use the AsCGI thing if you actually really need that (it's used for file uploads).

Delegates requests off to the request object it was initialized from.

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless { @_ }, $class;
    # $self->request->isa('HTTP::Request') or die;
    # $self->conn or die;
    # $self->queue or die;
    return $self;
}

# XXX check request content-type, if it isn't x-form-data then throw an error
# XXX pass in multiple param names, get back multiple param values
sub param {
    my $self = shift; 
    my $req = $self->{request};
    my @params = @{ $self->{params} ||= do {
        my $in = $req->uri; $in .= '&' . $req->content if $req->content;
        $in =~ s{^.*\?}{};
        my @params;
        for(split/[&]/, $in) { tr/+/ /; s{%(..)}{pack('c',hex($1))}ge; s{(.*?)=(.*)}{ push @params, $1, $2; ''; }e; };
        \@params;
    } };
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

sub conn :lvalue { $_[0]->{conn} }

sub request :lvalue { $_[0]->{request} }

1;
