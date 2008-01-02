# Gdb.pm
#
# perl debugger interface for vimDebug
#
# (c) eric johnson 2002-3020
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: Gdb.pm 93 2007-12-22 21:05:20Z eric $


package VimDebug::Debugger::Gdb;

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

use Data::Dumper;
use File::Spec;
use strict;
use vars qw(
    $dbgr
    $READ
    $WRITE
    $ERR
    $timeout

    $debuggerPath
    $debuggerPromptA
    $debuggerPromptB
    $debuggerPromptC
    $debuggerPrompt

    $path
    @commandLineOptions
);


# set some global variables
$DEBUG           = 1;
$debuggerPath    = "gdb";
$debuggerPromptA = '\(gdb\) ';
$debuggerPromptB = '';
$debuggerPromptC = '';
$debuggerPrompt  = "$debuggerPromptA";



# callback functions implemented

sub startDebugger {
   my $self               = shift or die;
      $path               = shift or die;
      @commandLineOptions = @_;

   $self->{breakPointList}  = {};
   $self->{breakPointCount} = 1;
   $self->{path} = $path;

   $WRITE = ""; $READ  = ""; $ERR   = "";

   my   @incantation = $debuggerPath;
   push(@incantation, $path);
   push(@incantation, @commandLineOptions);

   $timeout = timeout($TIME);
   $dbgr = start(\@incantation, '<pty<', \$WRITE,
                                '>pty>', \$READ,
                                '2>',    \$ERR,
                                $timeout);

   $self->findFirstPrompt();
   $WRITE .= "start\n";
   my $output   =  $self->getUntilPrompt();
   my $lineInfo = ($self->parseOutput($output) or $self->quit());
   return $lineInfo;
}

sub next {
   my $self = shift or die;

   $WRITE .= "n\n";
   my $output   =  $self->getUntilPrompt();
   my $lineInfo = ($self->parseOutput($output) or $self->quit());
   return $lineInfo;
}

sub step {
   my $self = shift or die;

   $WRITE .= "s\n";
   my $output   =  $self->getUntilPrompt();
   my $lineInfo = ($self->parseOutput($output) or $self->quit());
   return $lineInfo;
}

sub cont {
   my $self = shift or die;

   $WRITE .= "c\n";
   my $output   =  $self->getUntilPrompt();
   my $lineInfo = ($self->parseOutput($output) or $self->quit());
   return $lineInfo;
}


sub setBreakPoint {
   my $self       = shift or die;
   my $lineNumber = shift or die;
   my $fileName   = shift or die;
   my $ignoreMe;

   $fileName = File::Spec->rel2abs($fileName);
   $WRITE .= "break $fileName:$lineNumber\n";
   $ignoreMe = $self->getUntilPrompt(); # clear STDERR buffer

   return $DBGR_READY;
}


sub clearBreakPoint {
   my $self       = shift or die;
   my $lineNumber = shift or die;
   my $fileName   = shift or die;
   my $ignoreMe;


   $fileName = File::Spec->rel2abs($fileName);
   $WRITE .= "clear $fileName:$lineNumber\n";
   $ignoreMe = $self->getUntilPrompt(); # clear STDERR buffer

   return $DBGR_READY;
}

sub clearAllBreakPoints {
   my $self = shift or die;
   my $ignoreMe;

   $WRITE .= "clear\n";
   $ignoreMe = $self->getUntilPrompt(); # clear STDERR buffer

   return $DBGR_READY;
}

sub printExpression {
   my $self = shift or die;
   my $expression = shift or die;
   my $cmd = "p $expression";

   # write
   $WRITE .= $cmd . "\n";

   # read
   my $output = $self->getUntilPrompt();

   # parse output
   $output =~ s/$debuggerPrompt//os;
   $output =~ s/$cmd//os;
   $output = substr($output, 2);
   chop($output); # this is probably OS specific
   chop($output);
   return $output;
}


sub command {
   my $self = shift or die;
   my $command = shift or die;

   # TODO
   # need to catch the case where people set break points inside here so that
   # we can restore the break point when the debugger is restarted.

   # write
   $WRITE .= "$command\n";

   # read
   my $output = $self->getUntilPrompt();

   # parse output
   my $lineInfo = $self->parseOutput($output);
   return $lineInfo if $lineInfo;
   $output =~ s/$debuggerPrompt//os;
   $output =~ s/(.+):(\d+):(.+)/$3/os;
   return $output;
}

sub restart {
   my $self = shift or die;
   my $ignoreMe;

   # restart
   my $oldBreakPointList = $self->{breakPointList};
   $WRITE .= "kill\n";
   $WRITE .= "y\n";
   $ignoreMe = $self->getUntilPrompt(); # clear STDERR buffer
   $WRITE .= "start\n";
   my $output   =  $self->getUntilPrompt();
   my $lineInfo = ($self->parseOutput($output) or $self->quit());
   my $rv = $self->startDebugger($path, @commandLineOptions);
   return $rv unless $rv =~ /$LINE_INFO/;

   return $rv;
}



sub quit {
   $WRITE .= "q\n";
   $WRITE .= "y\n";
   $dbgr->finish();
   return $APP_EXITED;
}


sub findFirstPrompt {
   my $self     = shift or die;
   my $output   = $self->getUntilPrompt();
   my $lineInfo = $self->parseOutput($output) or $self->quit();
   return $lineInfo;
}

sub getUntilPrompt   {
   my $self = shift or die;
   my $output;

   my $ignoreMe = $READ; # clear STDOUT buffer
      $ignoreMe = $ERR;  # clear STDERR buffer

   eval {
      $dbgr->pump() until ($READ =~ /$debuggerPrompt/s);
   };
   if ($@ =~ /process ended prematurely/ and length($ERR) != 0) {
      print "$ERR\n" if $DEBUG;
      $dbgr->finish();
      $READ = $ERR;
      undef $@;
   }
   elsif ($@ =~ /process ended prematurely/) {
      print "process ended prematurely\n" if $DEBUG;
      $dbgr->finish();
      $READ = $APP_EXITED;
      undef $@;
   }
   elsif ($@) {
      die $@;
   }
   $timeout->reset();
   print "[$READ]\n" if $DEBUG;
   $output = $READ;
   $READ = '';

   $ignoreMe = $READ;  # clear STDOUT buffer
   $ignoreMe = $ERR;   # clear STDERR buffer

   return $output;
}

sub parseOutput {
   my $self   = shift or die;
   my $output = shift or die;

   if($output =~ /No;lkajsdfoiwqenvuiqweory./os) {
      $output =~ s/$debuggerPrompt//os;
      chomp($output);
      return $COMPILER_ERROR . $output;
   }
   elsif($output =~ /__libc_start_main \(\)/om)    {return $APP_EXITED}
   elsif($output =~ /Program exited with code /os) {return $APP_EXITED}
   elsif($output =~ /^  (.+)\:(\d+)\:\d+:\w+:/om)  {return "$LINE_INFO$2:$1"}
   else                                            {return 0}
}


1;
