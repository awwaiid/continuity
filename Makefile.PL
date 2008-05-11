use 5.006000;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Continuity',
    VERSION_FROM      => 'lib/Continuity.pm',
    ABSTRACT_FROM     => 'lib/Continuity.pm',
    AUTHOR            => 'Brock Wilcox <awwaiid@thelackthereof.org>',
    LICENSE           => 'perl',
    PREREQ_PM         => {
      HTTP::Daemon    => 1.36,
      Coro            => 4.37,
      Coro::Event     => 0,
    },
);
