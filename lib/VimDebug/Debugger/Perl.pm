# Perl.pm
#
# perl debugger interface for vimDebug
#
# (c) eric johnson 2002-3020
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: Perl.pm 93 2007-12-22 21:05:20Z eric $


package VimDebug::Debugger::Perl;

use IPC::Run qw(start pump finish timeout);
use VimDebug::Debugger qw(
  $COMPILER_ERROR
  $RUNTIME_ERROR
  $APP_EXITED
  $LINE_INFO
  $DBGR_READY
  $TIME
  $DEBUG
);

@ISA = qw(VimDebug::Debugger);

use strict;
use vars qw(
    $dbgr
    $READ
    $WRITE
    $ERR
    $timeout

    $debuggerPath
    $debuggerPrompt
);


# set some global variables

$DEBUG          = 0;
$debuggerPath   = "perl";
$debuggerPrompt = '  DB<+\d+>+ ';



# callback functions implemented

sub startDebugger {
   my $self               = shift or die;
   my $path               = shift or die;
   my @commandLineOptions = @_;


   $ENV{"PERL5DB"}     = 'BEGIN {require "perl5db.pl";}';
   $ENV{"PERLDB_OPTS"} = "ReadLine=0,ornaments=''";

   my   @incantation = $debuggerPath;
   push(@incantation, "-d");
   push(@incantation, $path);
   push(@incantation, @commandLineOptions);

   $timeout = timeout($TIME);
   $dbgr = start(\@incantation, '<pty<', \$WRITE,
                                '>pty>', \$READ,
                                '2>',    \$ERR,
                                $timeout);
   return $self->findFirstPrompt();
}

sub next {
   my $self = shift or die;

   $WRITE .= "n\n";
   my $ignoreMe = $READ; # clear STDOUT buffer
   my $stderr   = $self->getUntilPrompt();
   my $lineInfo = $self->parseOutput($stderr) or $self->quit();
   return $lineInfo;
}

sub step {
   my $self = shift or die;

   $WRITE .= "s\n";
   my $ignoreMe = $READ; # clear STDOUT buffer
   my $stderr   = $self->getUntilPrompt();
   my $lineInfo = $self->parseOutput($stderr) or $self->quit();
   return $lineInfo;
}

sub cont {
   my $self = shift or die;

   $WRITE .= "c\n";
   my $ignoreMe = $READ; # clear STDOUT buffer
   my $stderr   = $self->getUntilPrompt();
   my $lineInfo = $self->parseOutput($stderr) or $self->quit();
   return $lineInfo;
}


sub setBreakPoint {
   my $self       = shift or die;
   my $lineNumber = shift or die;
   my $fileName   = shift or die;
   my $ignoreMe;

   # set the file
   $WRITE .= "f $fileName\n";
   $ignoreMe = $READ;                   # clear STDOUT buffer
   $ignoreMe = $self->getUntilPrompt(); # clear STDERR buffer

   # set the line number
   $WRITE .= "b $lineNumber\n";
   $ignoreMe = $READ;                   # clear STDOUT buffer
   $ignoreMe = $self->getUntilPrompt(); # clear STDERR buffer

   return $DBGR_READY;
}


sub clearBreakPoint {
   my $self       = shift or die;
   my $lineNumber = shift or die;
   my $fileName   = shift or die;
   my $ignoreMe;


   # clear the file
   $WRITE .= "f $fileName\n";
   $ignoreMe = $READ;                   # clear STDOUT buffer
   $ignoreMe = $self->getUntilPrompt(); # clear STDERR buffer

   # set the line number
   $WRITE .= "B $lineNumber\n";
   $ignoreMe = $READ;                   # clear STDOUT buffer
   $ignoreMe = $self->getUntilPrompt(); # clear STDERR buffer

   return $DBGR_READY;
}

sub clearAllBreakPoints {
   my $self = shift or die;
   my $ignoreMe;

   $WRITE .= "B *\n";
   $ignoreMe = $READ;                   # clear STDOUT buffer
   $ignoreMe = $self->getUntilPrompt(); # clear STDERR buffer

   return $DBGR_READY;
}

sub printExpression {
   my $self = shift or die;
   my $expression = shift or die;

   # write
   $WRITE .= "x $expression\n";

   # read
   my $ignoreMe = $READ; # clear STDOUT buffer
   my $stderr = $self->getUntilPrompt();

   # parse output
   $stderr =~ s/$debuggerPrompt//os;
   chomp($stderr);
   chomp($stderr);
   chomp($stderr);
   return $stderr;
}


sub command {
   my $self = shift or die;
   my $command = shift or die;


   # write
   $WRITE .= "$command\n";

   # read
   my $ignoreMe = $READ; # clear STDOUT buffer
   my $stderr = $self->getUntilPrompt();

   # parse output
   my $lineInfo = $self->parseOutput($stderr);
   return $lineInfo if $lineInfo;
   $stderr =~ s/$debuggerPrompt//os;
   return $stderr;

}

sub restart {
   my $self = shift or die;

   $WRITE .= "R\n";
   return $self->findFirstPrompt();
}


sub quit {
   $WRITE .= "q\n";
   $dbgr->finish();
   return $APP_EXITED;
}


sub findFirstPrompt {
   my $self     = shift or die;
   my $stderr   = $self->getUntilPrompt();
   my $lineInfo = $self->parseOutput($stderr) or $self->quit();
   my $ignoreMe = $READ; # clear STDOUT buffer
   return $lineInfo;
}

sub getUntilPrompt   {
   my $self = shift or die;
   my $stderr;

   $dbgr->pump() until $ERR =~ /$debuggerPrompt/s;
   $timeout->reset();
   print "[$ERR]\n" if $DEBUG;
   $stderr = $ERR;
   $ERR = '';

   return $stderr
}

sub parseOutput {
   my $self   = shift or die;
   my $output = shift or die;

   # take care of the problem case when we hit an eval() statement
   # example: main::function((eval 3)[debugTestCase.pl:5]:1):      my $foo = 1
   # this will turn that example debugger output into:
   #          main::function(debugTestCase.pl:5):      my $foo = 1
   if ($output =~  /\w*::(\w*)\(+eval\s+\d+\)+\[(.*):(\d+)\]:\d+\):/om) {
       $output =~ s/\w*::(\w*)\(+eval\s+\d+\)+\[(.*):(\d+)\]:\d+\):/::$1($2:$3):/m;
   }

   if($output =~ /aborted due to compilation error/os) {
      $output =~ s/.*`man perldebug' for more help\.\n\n//os;
      my $i = index($output, 'Debugged program terminated.  Use q');
      $output = substr($output, 0, $i);
      chomp($output);
      return $COMPILER_ERROR . $output;
   }
   elsif($output =~ / at .* line \d+/om) {
   # if program dies
      my $i = index($output, 'Debugged program terminated.  Use q');
      $output = substr($output, 0, $i);
      chomp($output);
      return $RUNTIME_ERROR . $output;
   }
   elsif($output =~ /\w*::(\w*)?\(+(.+):(\d+)\)+:/om) {return "$LINE_INFO$3:$2"}
   elsif($output =~ /\/perl5db.pl:/os)                      {return $APP_EXITED}
   elsif($output =~ /Use .* to quit or .* to restart/os)    {return $APP_EXITED}
   elsif($output =~ /\' to quit or \`R\' to restart/os)     {return $APP_EXITED}
   else                                                               {return 0}
}


1;
