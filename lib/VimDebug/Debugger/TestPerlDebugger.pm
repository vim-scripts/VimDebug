# TestPerlDebugger.pm
#
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
# your test code which will be debugged by this script should go in the t/
# directory with all the other tests.  for example, t/perlTest contains perl
# test code to be debugged.  your test code must comply with the following
# rules in order to pass the tests:
#
#
# line  1:
# line  2:
# line  3:
# line  4:
# line  5: statement 1;
# line  6: statement 2;
# line  7: statement 3;
# line  8: statement 4;
# line  9:
# line 10: function call to function contain4 lines of code
# line 11:
# line 12:
# line 13:
# line 14:


package VimDebug::Debugger::TestPerlDebugger;

use Cwd;
use VimDebug::Debugger qw($APP_EXITED $LINE_INFO $TIME $DEBUG);
use VimDebug::Debugger::Perl;
use Test::Unit::TestCase;

@ISA = qw(Test::Unit::TestCase);

use strict;

use constant FILE0 => 't/Perl.testCode';



sub new {
   my $self = shift()->SUPER::new(@_);
   $self->{dbgr} = VimDebug::Debugger::Perl->new();
   return $self;
}

sub set_up {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   $dbgr->startDebugger(FILE0);
}

sub tear_down {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   $dbgr->quit();
}

sub testStep {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv;
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $self->assert($rv eq $LINE_INFO . "10:" . FILE0, $rv);
}

sub testNext {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv;
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->step();
   $rv = $dbgr->next();
   $self->assert($rv eq $LINE_INFO . "9:" . FILE0, $rv);
}

sub testCont {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv   = $dbgr->cont();
   $self->assert($rv eq $APP_EXITED, $rv);
}

sub testRestart {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv;
   $self->testCont();
   $rv = $dbgr->restart();
   $rv = $dbgr->next();
   $self->assert($rv eq $LINE_INFO . "4:" . FILE0, $rv);
}

sub testBreakPoints {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv;
   $rv = $dbgr->setBreakPoint(10, FILE0);
   $rv = $dbgr->cont();
   $self->assert($rv eq $LINE_INFO . "10:" . FILE0, $rv);
   $self->testRestart();
   $rv = $dbgr->cont();
   $self->assert($rv eq $LINE_INFO . "10:" . FILE0, $rv);
   $rv = $dbgr->clearBreakPoint(10, FILE0);
   $self->testRestart();
   $rv = $dbgr->cont();
   $self->assert($rv eq $APP_EXITED, $rv);
}

sub testPrintExpression {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $rv;
   $rv = $dbgr->printExpression('1+1');
   $self->assert($rv =~ /2/, $rv);
}

sub testCommand {
   my $self = shift or die;
   my $dbgr = $self->{dbgr};
   my $bool;
   my $rv;
   $rv = $dbgr->command("n");
   $self->assert($rv eq $LINE_INFO . "4:" . FILE0, $rv);
   $rv = $dbgr->command("beepinfoodoo123444e");
   $self->assert(scalar($rv =~ /\n/s), ">>" . $rv . "<<"); # ??
   $rv = $dbgr->command("c");
   $self->assert($rv eq $APP_EXITED, $rv);
}


1;
# vim: shiftwidth=3: tabstop=3: expandtab
