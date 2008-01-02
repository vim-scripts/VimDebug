#!/usr/bin/perl

use File::Which;
use VimDebug::Debugger::Test;
use VimDebug::Debugger::Ruby;
use Test::More;

if (not defined File::Which::which($VimDebug::Debugger::Ruby::debuggerPath)) {
   plan skip_all => "can't find ruby";
}

my $test = VimDebug::Debugger::Test->new(debuggerName => 'Ruby');
Test::Class->runtests($test);
