
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

