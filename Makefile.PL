use 5.006000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Continuity',
    VERSION_FROM      => 'lib/Continuity.pm', # finds $VERSION
    PREREQ_PM         => {
      HTTP::Daemon    => 1.36,
      Coro::Event     => 3.6,
      Coro            => 3.6,
      Module::Reload  => 1.07,
      Coro::Event     => 2.1,
      #FCGI            => 0.67,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Continuity.pm', # retrieve abstract from module
       AUTHOR         => 'Brock Wilcox <awwaiid@thelackthereof.org>') : ()),
);
