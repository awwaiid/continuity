use strict;
use inc::Module::Install;

# Metadata
name 'Continuity';
all_from 'lib/Continuity.pm';

# Dependencies
requires 'HTTP::Daemon'     => '1.36';
requires 'IO::AIO'          => '2.3';
requires 'Event'            => '0';
requires 'AnyEvent'         => '0';
requires 'Coro'             => '4.03';

# Suggestions
recommends 'Module::Reload' => '1.07';
recommends 'FCGI'           => '0.67';

# Other stuff
no_index directory => 'ex';
no_index package   => 'HTTP::Daemon';

auto_install;
WriteAll;

