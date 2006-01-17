package Continuity;

our $VERSION = '0.5';

1;
__END__

=head1 NAME

Continuity - Simplify web apps through abstraction (such as continuations)

=head1 SYNOPSIS

  use Continuity::Server::Simple;
  $server = new Continuity::Server::Simple;
  $server->loop();

  sub main {
    # must do a substr to chop the leading '/'
    $name = substr($server->get_request->url->path,1) || 'World';
    print "Hello, $name!";
    $name = substr($server->get_request->url->path,1) || 'World';
    print "Hello to you too, $name!";
  }

=head1 DESCRIPTION

This module is just for documentation.

Continuity seeks to be a library (not a framework) to simplify web
applications.At the core is a continuation server, which inverts control back
to the programmer. This is ALPHA software, and feedback/code is welcomed.

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

