
use strict;
use warnings;

BEGIN { require 5.006; }

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Debugger interface to many debuggers',
  'AUTHOR' => 'Eric Johnson <vimdebug at iijo dot org>',
  'BUILD_REQUIRES' => {
    'English' => '0',
    'File::Which' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'VimDebug',
  'EXE_FILES' => [
    'bin/vddTester',
    'bin/vdd'
  ],
  'LICENSE' => 'perl',
  'NAME' => 'VimDebug',
  'PREREQ_PM' => {
    'Carp' => '0',
    'Cwd' => '0',
    'File::Basename' => '0',
    'File::Spec' => '0',
    'Getopt::Long' => '0',
    'IO::Pty' => '0',
    'IPC::Run' => '0',
    'UNIVERSAL' => '0',
    'vars' => '0'
  },
  'VERSION' => '0.5',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



