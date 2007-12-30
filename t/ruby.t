#!/usr/bin/perl

use VimDebug::Debugger::Test;
my $ruby = VimDebug::Debugger::Test->new(debuggerName => 'Ruby');
Test::Class->runtests($ruby);
