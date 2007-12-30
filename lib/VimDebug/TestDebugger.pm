# TestPerlDebugger.pm
#
# (c) eric johnson 2002-3020
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: TestDebugger.pm 65 2005-10-04 22:32:14Z eric $


# debugger packages should pass all of the tests in this package.
#
# your test code must comply with the following simple rules in order to pass
# the tests:
#
# - the file name must be: t/<PackageName>.testCode
#   for example, t/Perl.testCode contains the perl debugger test code
# - the first step() will put you at line 4
# - the first next() will put you at line 4
# - a break point will be set at line 9


package VimDebug::TestDebugger;

use Cwd;
use File::Basename;
use File::Find;
use VimDebug::Debugger qw($APP_EXITED $LINE_INFO $TIME $DEBUG);
use Test::Unit::TestCase;

@ISA = qw(Test::Unit::TestCase);

use strict;

use vars qw(@testModules);

use constant STEP  => 4;
use constant NEXT  => 4;
use constant BREAK => 9;



sub moduleIsAlreadyInList {
   my $new     = shift or die;
   my @matched = grep {$_ eq $new} @testModules;
   return 1 if scalar(@matched) != 0;
   return 0 if scalar(@matched) == 0;
}

sub wanted {
   my $name = $File::Find::name;
   my ($file, $path, $suffix) = fileparse($name, qr{\.pm});
   if ($name !~ /VimDebug\/Debugger\/Test.*\.pm$/ and
       $name =~ /VimDebug\/Debugger\/.*\.pm$/) {

      push(@testModules, $file) unless moduleIsAlreadyInList($file);

   }
}

sub findTestModules {
   my $self = shift or die;
   my @dirList = grep {-e $_ && !/\./} @INC;
   @testModules = ();
   find(\&wanted, @dirList);
}

sub loadTestModules {
   my $self = shift or die;
   foreach my $module (@testModules) {

      # load module
      my $moduleName = 'VimDebug/Debugger/' . $module . '.pm';
      require $moduleName ;

      # create debugger object
      my $debuggerName = 'VimDebug::Debugger::' . $module;
      my $dbgr = eval $debuggerName . "->new();";
      die "no such module exists: $module" unless defined $dbgr;

      # save it
      $self->{$module} = $dbgr;
   }
}

sub new {
   my $self = shift()->SUPER::new(@_);

   $self->findTestModules();
   $self->loadTestModules();

   return $self;
}

# determines what the name of the file containing the test code should be
sub getTestCode {
   my $self = shift or die;
   my $file = shift or die;
   $file =~ s/^Test//;
   return "t/$file.testCode";
}

sub set_up {
   my $self = shift or die;
   foreach my $module (@testModules) {
      my $file = $self->getTestCode($module);
      my $dbgr = $self->{$module};
      $dbgr->startDebugger($file);
   }
}

sub tear_down {
   my $self = shift or die;
   foreach my $module (@testModules) {
      my $dbgr = $self->{$module};
      $dbgr->quit();
   }
}

sub testStep {
   my $self = shift or die;
   my ($rv, $dbgr, $file);
   foreach my $module (@testModules) {
      $file = $self->getTestCode($module);
      $dbgr = $self->{$module};
      $rv   = $dbgr->step();
      $self->assert($rv eq $LINE_INFO . STEP . ":$file", "$module : $rv");
   }
}

sub testNext {
   my $self = shift or die;
   my ($rv, $dbgr, $file);
   foreach my $module (@testModules) {
      $file = $self->getTestCode($module);
      $dbgr = $self->{$module};
      $rv   = $dbgr->next();
      $self->assert($rv eq $LINE_INFO . NEXT . ":$file", "$module : $rv");
   }
}

sub testCont {
   my $self = shift or die;
   my ($rv, $dbgr, $file);
   foreach my $module (@testModules) {
      $dbgr = $self->{$module};
      $rv   = $dbgr->cont();
      $self->assert($rv eq $APP_EXITED, "$module : $rv");
   }
}

sub testRestart {
   my $self = shift or die;
   my ($rv, $dbgr, $file);
   foreach my $module (@testModules) {
      $file = $self->getTestCode($module);
      $dbgr = $self->{$module};
      $dbgr->cont();
      $dbgr->restart();
      $rv = $dbgr->next();
      $self->assert($rv eq $LINE_INFO . NEXT . ":$file", "$module : $rv");
   }
}

sub testBreakPoints {
   my $self = shift or die;
   my ($rv, $dbgr, $file);
   foreach my $module (@testModules) {
      $file = $self->getTestCode($module);
      $dbgr = $self->{$module};

      $rv = $dbgr->setBreakPoint(BREAK, $file);
      $rv = $dbgr->cont();
      $self->assert($rv eq $LINE_INFO . BREAK . ":$file", "$module : $rv");
      $rv = $dbgr->cont();
      $self->assert($rv eq $APP_EXITED, "$module : $rv");

      $self->testRestart();
      $rv = $dbgr->cont();
      $self->assert($rv eq $LINE_INFO . BREAK . ":$file", "$module : $rv");
      $rv = $dbgr->cont();
      $self->assert($rv eq $APP_EXITED, "$module : $rv");

      $rv = $dbgr->clearBreakPoint(BREAK, $file);
      $self->testRestart();
      $rv = $dbgr->cont();
      $self->assert($rv eq $APP_EXITED, "$module : $rv");
   }
}

sub testPrintExpression {
   my $self = shift or die;
   my ($rv, $dbgr, $file);
   foreach my $module (@testModules) {
      $dbgr = $self->{$module};
      $rv = $dbgr->printExpression('1+1');
      $self->assert($rv =~ /2/, "$module : $rv");
   }
}

sub testCommand {
   my $self = shift or die;
   my ($rv, $dbgr, $file);
   foreach my $module (@testModules) {
      $dbgr = $self->{$module};
      $rv = $dbgr->command("beepinfoodoo123444e");
      $self->assert(scalar($rv =~ /\n/s), "$module : $rv");
   }
}


1;
# vim: shiftwidth=3: tabstop=3: expandtab
