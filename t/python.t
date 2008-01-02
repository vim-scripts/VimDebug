#!/usr/bin/perl

use File::Which;
use VimDebug::Debugger::Test;
use VimDebug::Debugger::Python;
use Test::More;

if (not defined File::Which::which($VimDebug::Debugger::Python::debuggerPath)) {
   plan skip_all => "can't find python, so not testing python";
}

use VimDebug::Debugger::Test;
my $test = VimDebug::Debugger::Test->new(debuggerName => 'Python');
Test::Class->runtests($test);
