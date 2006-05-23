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
sub param {
    my $self = shift; 
    my $req = $self->{request};
    my @params = @{ $self->{params} ||= do {
        my $in = $req->uri; $in .= '&' . $req->content if $req->content;
        $in =~ s{^.*\?}{};
        my @params;
        for(split/[&]/, $in) { tr/+/ /; s{%(..)}{pack('c',hex($1))}ge; s{(.*?)=(.*)}{ push @params, $1, $2; STDERR->print("debug: setting $1 to $2\n"); ''; }e; };
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

sub next {
    # called by the user's program from the context of their coroutine
    $_[0]->conn and $_[0]->conn->close;
    $_[0] = $_[0]->queue->get; 
}

sub conn :lvalue { $_[0]->{conn} }

sub print { 
    my $self = shift; 
    fileno $self->{conn} or return undef;
    Coro::Event->io( fd => $self->{conn}, poll => 'w', )->next;
    $self->{conn}->print(@_); 
}

sub request :lvalue { $_[0]->{request} }

sub queue :lvalue { $_[0]->{queue} }

sub AUTOLOAD {
    my $method = $AUTOLOAD; $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    my $self = shift;
STDERR->print("debug XXX: ", ref $self, " proxying call to method $method in ob ", ref $self->{request}, "\n");
    $self->{request}->can($method)->($self->{request}, @_);
}


1;
