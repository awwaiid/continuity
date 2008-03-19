
package Continuity::Request;

=head1 NAME

Continuity::Request - Simple HTTP::Request-like API for requests inside Continuity

=head1 SYNOPSIS

  sub main {
    my $request = shift;
    $request->print("Hello!");
    $request->next;

    # ...

    $name = $request->param('name');
  }

=head1 METHODS

=head2 $request->next

Suspend execution until a new Web request is available.

=head2 $name = $request->param("name");  

Fetch a CGI POST/GET parameter.

=head2 @param_names = $request->param();

Fetch a list of posted parameters.

=head2 $request->print("Foo!\n");

Write output (eg, HTML).

Since Continuity juggles many concurrent requests, it's necessary to explicitly
refer to requesting clients, like C<< $request->print(...) >>, rather than
simply doing C<< print ... >>.

=head2 $request->set_cookie(CGI->cookie(...));

=head2 $request->set_cookie(name => 'value');

Set a cookie to be sent out with the headers, next time the headers go out
(next request if data has been written to the client already, otherwise this
request).  (May not yet be supported by the FastCGI adapter yet.)

=head2 $request->uri();

Straight from L<HTTP::Request>, returns a URI object.  (Probably not yet
supported by the FastCGI adapter.)

=head2 $request->method();

Returns 'GET', 'POST', or whatever other HTTP command was issued.  Continuity
currently punts on anything but GET and POST out of paranoia.

=head2 $request->send_headers("X-HTTP-Header: blah\n", $h2)

Send this in the headers

=head1 INTERNAL METHODS

=head2 $request->send_basic_header();

Continuity does this for you, but it's still part of the API of
Continuity::Request objects.

=head2 $request->end_request();

Ditto above.

=head2 $request->send_static();

Controlled by the C<< staticp => sub { ... } >> argument pair to the main
constructor call to C<< Continuity->new() >>.

=head1 DESCRIPTION

This module contains no actual code.
It only establishes and documents the interface actually implemented in
L<Continuity::Adapt::FCGI>, L<Continuity::Adapt::HttpDaemon>, and,
perhaps eventually, other places.

=head1 SEE ALSO

=over 1

=item L<Continuity>

=item L<Continuity::Adapt::FCGI>

=item L<Continuity::Adapt::HttpDaemon>

=back

=cut

1;

