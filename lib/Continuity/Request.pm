
package Continuity::Request;


=head1 NAME

Continuity::Request - Simple HTTP::Request-like API for requests inside Continuity

=head1 SYNOPSIS

  $request->next;

Suspends execution until a new Web request is available.

  $request->param("name");  

Fetches a CGI POST/GET parameter.

  @param_names = $request->param();

Fetches a list of posted parameters.

  $request->print("Foo!\n");

Writes output (eg, HTML).
Since Continuity juggles many concurrent requests, 
it's necessary to explicitly refer to requesting clients, like C<< $request->print() >>, 
rather than simply doing C<< print() >>.

  $request->set_cookie(CGI->cookie(...));

Set a cookie to be sent out with the headers, next time the headers go out
(next request if data has been written to the client already, otherwise this request).
(May not yet be supported by the FastCGI adapter yet.)

  $request->uri();

Straight from L<HTTP::Request>.
Values seem strange to me.
(Probably not yet supported by the FastCGI adapter.)

  $request->method();

Returns 'GET', 'POST', or whatever other HTTP command was issued.
Continuity currently punts on anything but GET and POST out of paranoia.
(May not be supported in the FastCGI adapter and the HTTP::Daemon adapter only proxies it to 
the underlaying HTTP::Request object through AUTOLOAD -- it's documented here in the request
object API because it should eventually, some day, be a well supported, tested part of the API.)

  $request->send_basic_header();

Internal use.  Continuity does this for you, but it's still part of the API of Continuity::Request objects.

  $request->end_request();

Internal use.  Ditto above.

  $request->send_static();

Internal use.  Controlled by the C<< staticp => sub { ... } >> argument pair to the
main constructor call to C<< Continuity->new() >>.


=head1 DESCRIPTION

This module contains no actual code.
It only establishes the interface actually implemented in
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

