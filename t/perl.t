#!/usr/bin/perl

use VimDebug::Debugger::Test;
my $perl = VimDebug::Debugger::Test->new(debuggerName => 'Perl');
Test::Class->runtests($perl);
