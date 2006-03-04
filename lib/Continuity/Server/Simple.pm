
package Continuity::Server::Simple;

use strict;
use Coro::Cont;
use base 'Continuity::Server';

=head1 NAME

Continuity::Server::Simple - Simplified use of L<Continuity::Server>

=head1 DESCRIPTION

This is a simplified interface to L<Continuity::Server>. It is quite possible
that this will one day be obsolete because of default options when using the
standard server.

=head1 METHODS

=over

=cut


sub execCont {

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

=item $server->get_request

Get a request from the server. All this really does (right now) is yield the
running continuation, returning control to the looping Continuity::Server
process

=cut

sub get_request {
  my ($self, $retval) = @_;
  yield $retval;
  my ($request) = @_;
  return $request;
}

package HTTP::Request;

use strict;
use CGI;
use HTTP::Request::AsCGI;

# A minor ease-of-use extension for HTTP::Request
# Given an HTTP::Request, return a nice hash of name/params
# This is really just a thin wrapper around HTTP::Request::Params
sub params {
  my ($request) = @_;
  my $cgi = $request->asCGI;
  my $vars = $cgi->Vars;
  return $vars;
}

sub asCGI {
  my ($request) = @_;
  my $s = HTTP::Request::AsCGI->new($request)->setup;
  my $cgi = new CGI;
  return $cgi;
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

