
package Continuity::Middleware::SessionP;

# could set cookies to work transparently or could use memcached or the like to distributedly remember which client-side IPs are associated with 
# which server side IPs

# alright, let's try cookies first.

use parent 'Plack::Middleware';

our $cookie_name = 'sessionp';

sub call {
    my($self, $env) = @_;

    my ($cookie) =  map $_->[1],
      grep $_->[0] eq $cookie_name,
      map [ m/(.*?)=(.*)/ ],
      split /; */,
      $env->{HTTP_COOKIE} || '';

warn "cookie: $cookie";
warn "host: " . $env->{HTTP_HOST};

    # XXX if HTTP_HOST is us
    my $res = $self->app->($env);
    # XXX otherwise, back-end proxy to there

    if( ! $cookie ) {
        push @{ $res->[1] }, "Set-Cookie" => "$cookie";
    }

    return $res;
}

1;
