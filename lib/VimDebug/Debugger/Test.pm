# (c) eric johnson 2002-3020
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: TestPerlDebugger.pm 67 2005-10-04 22:35:52Z eric $
#
#
# ALL DEBUGGER PACKAGES SHOULD PASS ALL TESTS
# ALL DEBUGGER PACKAGES SHOULD PASS ALL TESTS
# ALL DEBUGGER PACKAGES SHOULD PASS ALL TESTS
#
# read the perldoc at the end of this file to see how to do this.
#
# your test code which will be debugged by this script should go in the t/
# directory with all the other tests.  for example, t/perlTest contains perl
# test code to be debugged.  your test code must comply with the following
# rules in order to pass the tests:
#
# line  1:
# line  2:
# line  3:
# line  4:
# line  5: function A
# line  6: function A
# line  7: function A
# line  8: function A
# line  9:
# line 14: statement
# line 15: statement
# line 16: statement
# line 17: statement
# line  9:
# line 10: function call to function A
# line 11:
# line 12: statement
# line 12: statement
# line 12: statement
# line 12: statement
# line 18:


package VimDebug::Debugger::Test;

use Cwd;
use VimDebug::Debugger qw($APP_EXITED $LINE_INFO $TIME $DEBUG);
use Test::More;

use base Test::Class;
use strict;


sub createDebugger : Test(startup) {
   my $self = shift or die;

   die "debuggerName not defined" unless exists $self->{debuggerName};

   # load module
   my $moduleName = 'VimDebug/Debugger/' . $self->{debuggerName} . '.pm';
   require $moduleName ;

   # create debugger object
   my $className = 'VimDebug::Debugger::' . $self->{debuggerName};
   $self->{dbgr} = eval $className . "->new();";
   die "no such module exists: $className" unless defined $self->{dbgr};

   # derive filename where test code is located
   $self->{testCode} = "t/" . $self->{debuggerName} . ".testCode";
}

sub startDebugger : Test(setup) {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   $dbgr->startDebugger($self->{testCode});
}

sub quitDebugger : Test(teardown) {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   $dbgr->quit();
}

sub step : Test(1) {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv;
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step(); # some dbgrs skip over the function call
   $rv = $dbgr->step(); # some dbgrs stop on the function call
   ok($rv =~ /$LINE_INFO(5|6):$self->{testCode}/) or diag($rv);
}

sub next : Test(1) {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv;
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->next(); # some dbgrs skip over the function call
   $rv = $dbgr->next(); # some dbgrs stop on the function call
   ok($rv =~ /$LINE_INFO(18|19):$self->{testCode}/) or diag($rv);
}

sub cont : Test(1) {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv   = $dbgr->cont();
   ok($rv eq $APP_EXITED) or diag($rv);
}

sub restart : Test(2) {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv;
   $self->cont();
   $rv = $dbgr->restart(); # some dbgrs restart on the first line of code
   $rv = $dbgr->next();    # some dbgrs restart and pause before the first line
   ok($rv =~ /$LINE_INFO(11|12):$self->{testCode}/) or diag($rv);
}

sub breakPoints : Test(7) {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv;
   $rv = $dbgr->setBreakPoint(13, $self->{testCode});
   $rv = $dbgr->cont();
   ok($rv eq $LINE_INFO . "13:" . $self->{testCode}) or diag($rv);
   $self->restart();
   $rv = $dbgr->cont();
   ok($rv eq $LINE_INFO . "13:" . $self->{testCode}) or diag($rv);
   $rv = $dbgr->clearBreakPoint(13, $self->{testCode});
   $self->restart();
   $rv = $dbgr->cont();
   ok($rv eq $APP_EXITED) or diag($rv);
}

sub printExpression : Test(1) {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv;
   $rv = $dbgr->printExpression('1+1');
   ok($rv =~ /2/) or diag($rv);
}

sub command : Test(3) {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $bool;
   my $rv;
   $rv = $dbgr->command("n"); # some dbgrs start on the first line of code
   $rv = $dbgr->command("n"); # some dbgrs start and pause before the first line
   ok($rv =~ /$LINE_INFO(12|13):$self->{testCode}/) or diag($rv);
   $rv = $dbgr->command("beepinfoodoo123444e");
   ok(scalar($rv =~ /\n/s)) or diag("bad command: >>" . $rv . "<<");
   $rv = $dbgr->command("c");
   ok($rv eq $APP_EXITED) or diag($rv);
}


1;
