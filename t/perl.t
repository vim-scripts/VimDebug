#!/usr/bin/perl

use VimDebug::Debugger::Test;
my $test = VimDebug::Debugger::Test->new(debuggerName => 'Perl');
Test::Class->runtests($test);
