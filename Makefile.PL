use strict;
use inc::Module::Install;

# Metadata
name 'Continuity';
all_from 'lib/Continuity.pm';

# Dependencies
requires 'HTTP::Daemon'     => '1.36';
requires 'Event'            => '0';
requires 'AnyEvent'         => '0';
requires 'IO::AIO'          => '2.3';
requires 'Coro'             => '3.63';

# Suggestions
recommends 'Module::Reload' => '1.07';
recommends 'FCGI'           => '0.67';

# Other stuff
no_index directory => 'ex';
no_index directory => 'doc';
no_index package   => 'HTTP::Daemon';

auto_install;
WriteAll;

