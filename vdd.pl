#!/usr/bin/perl -w
#
# vdd.pl
# Vim Debugger Daemon
#
#
# TODO
# -- write some clear all breakpoints code?
# -- allow multipe vimDebug sessions at once (one vimDebug session per vim
#    session, though right?)
#
#
# (c) eric johnson 09.31.2002
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: vdd.pl,v 1.14 2003/06/02 20:30:35 eric Exp eric $

use strict;
use Getopt::Long;

use vars qw(
             $unix

             $debuggerName
             $sourcePath
             @commandLineOptions

             $help_option

             $TOvim
             $FROMvim

             $debuggerReady

             $debugger

             $sigIntCaught
             $quitting

             $DEBUG
                               );



#### BEGIN stuff the user can change ###########################################
$unix = 1; # valid values are 1 and 0
#### END stuff the user can change #############################################



# global variables {{{

$DEBUG = 0;

$TOvim =   ".vddTOvim";   # fifo to write to VIM
$FROMvim = ".vimTOvdd";   # fifo to read from VIM

$debuggerReady = "debuggerReady";  # message to send to vim to indicate the
                                   # the debugger is done thinking

$sigIntCaught = 0;
$quitting     = 0;

# }}}



setupSignalHandlers();
getCommandLineOptions();
init();
main();



### subs #######################################################################

# sub setupSignalHandlers   {{{
# install signal handlers
sub setupSignalHandlers   {
   $SIG{INT} = \&handleSignal;
   # $SIG{TSTP} = 'DEFAULT';
   # $SIG{TERM} = \&handleSignal;
}
# }}}
# sub handleSignal   {{{
sub handleSignal   {
#   my $signal = shift;

   _kill();

#   $SIG{$signal} = \&handleSignal;

#   if( $quitting )   {
#      # then we've already started quitting and so we just try to force exit
#      # without the graceful quit
#      print "Attempting to force exit...\n";
#      _kill();
#   }
#
#   if( $sigIntCaught )   {
#      # the user has alrady hit INT and so we now force an exit
#      print "Caught another SIG$signal\n";
#      _kill();
#   }
#   else   {
#      # if i were really energetic i'd probably try to gracefully exit
#      # the perl debugger while in the middle of a step or whatever.
#      # it would look something like whats below.  i mean the bottom of this
#      # sub.
#
#      print "Caught SIG$signal\n";
#      $sigIntCaught = 1;
#      _kill();
#   }
#
#    if( $running_query ) {
#      if(defined $cursth) {
#        print "Attempting to cancel query...\n";
#        debugmsg(1, "canceling statement handle");
#        my $ret = $cursth->cancel();
#        $cursth->finish;
#      }
#    } elsif(!$connected) {
#      quit();
#
#      if(defined $cursth) {
#        print "Attempting to cancel query...\n";
#        debugmsg(1, "canceling statement handle");
#        my $ret = $cursth->cancel();
#        $cursth->finish;
#      }
#    }

}
# }}}
# sub getCommandLineOptions   {{{
sub getCommandLineOptions   {

   # call GetOptions to parse the command line
   Getopt::Long::Configure( qw( permute ) );
   $Getopt::Long::ignorecase = 0;
   usage( 1 ) unless GetOptions(
         "help|h|?"      => \$help_option
   );

   usage() if $help_option;
   usage() unless( $#ARGV >= 1 );

   $debuggerName       = shift @ARGV;   # which debugger to use
   $sourcePath         = shift @ARGV;   # path to source you want to debug
   @commandLineOptions = @ARGV;         # command line options of program
}
# }}}
# sub usage   {{{
sub usage   {
   print "
usage: vdd [options] DEBUGGER SOURCEPATH [debuggerCommandLineOptions]

the vim debugger daemon.

valid values for the DEBUGGER are: PerlDebugger, Jdb, and Gdb.
SOURCEPATH is the location of the source code being debugged.

";

   exit( 0 );
}
# }}}
# sub init   {{{
sub init   {
   # modify @INC in order to find the debugger modules
   # $0 is the name (includes path) of this script
   ( my $path, my $fileName ) = getPathAndFileName( $0 );
   eval "use lib '$path'";

   require Utils;  # load up some useful utility functions.
}
# }}}


sub main   {

   Utils->makeNamedPipe( $FROMvim );
   Utils->makeNamedPipe( $TOvim );
   startDebugger();

   # loop until request to exit
   while( 1 )   {
      my $command = readFromVim();     # blocks until there is something to read

      for( $command )   {   # this works like a switch statement
         /^next$/o                     and _next( $command );
         /^step$/o                     and step( $command );
         /^break:\d+:\S+$/o            and setBreakPoint( $command );
         /^clearBreakPoint:\d+:\S+$/o  and clearBreakPoint( $command );
         /^cont$/o                     and cont();
         /^printExpressionValue:.+$/o  and printExpressionValue( $command );
         /^command:.+$/o               and command( $command );
         /^restart$/o                  and restart();
         /^quit$/o                     and quit();
      }
   }

}


# sub getPathAndFileName {{{
# seperate out the path and file name from $file
#
# parameters
#    $file: a file name that may or may not also have a path.
#           example: '/path/foo/fileName' or 'fileName'
# returns ( $path, $fileName )
sub getPathAndFileName {
   my $file = shift;

   if( $file =~ /(^.*\/)(.*)$/ )   {
      return ( $1, $2 );
   }
   else   {
      return ( "", $file );
   }
}
# }}}
# sub deleteNamedPipes   {{{
sub deleteNamedPipes   {
   close $FROMvim;
   close $TOvim;

   unlink $FROMvim;
   unlink $TOvim;
}
# }}}
# sub END   {{{
sub END   {
   deleteNamedPipes();
}
# }}}

# sub readFromVim   {{{
# blocks until there is something to read
sub readFromVim   {
   open( FROMvim, "< $FROMvim" ) or quit();
   return <FROMvim>;
}
# }}}
# sub sendToVim   {{{
# blocks until someone reads
# obviously this stuff isn't going to work on windows.  for windows we
# should use gvim --remote stuff.  i don't want to use gvim on unix because
# then you can't debug over a telnet session.
sub sendToVim   {
   my $stuffToSend = shift;

   open( TOvim, "> $TOvim" ) or quit();
   print "\nsending to vim: \n>$stuffToSend<\n" if $DEBUG;
   print TOvim $stuffToSend;
   close( TOvim );
}
# }}}



### debugger related subroutines ###############################################

# sub startDebugger   {{{
sub startDebugger   {

   # load module
   my $moduleName = $debuggerName . ".pm";
   require $moduleName;

   # create debugger object
   $debugger = eval $debuggerName . "->new();";
   die "no such module exists: $moduleName" if !defined( $debugger );

   $debugger->initialize();
   $debugger->startDebugger( $sourcePath, @commandLineOptions );
   $debugger->findFirstPrompt( $sourcePath );

   sendToVim( $debuggerReady );
}
# }}}
# sub _next   {{{
# "_next()" is named funny because "next" is a perl keyword
sub _next   {
   sendToVim( $debugger->_next() );
}
# }}}
# sub step   {{{
sub step   {
   sendToVim( $debugger->step() );
}
# }}}
# sub cont   {{{
sub cont   {
   sendToVim( $debugger->cont() );
}
# }}}
# sub setBreakPoint   {{{
sub setBreakPoint   {
   my $command = shift;
   $command =~ /^break:(\d+):(.*)$/o;
   my $lineNumber = $1;
   my $fileName = $2;

   $debugger->setBreakPoint( $lineNumber, $fileName );
}
# }}}
# sub clearBreakPoint   {{{
sub clearBreakPoint   {
   my $command = shift;
   $command =~ /^clearBreakPoint:(\d+):(.*)$/o;
   my $lineNumber = $1;
   my $fileName = $2;

   $debugger->clearBreakPoint( $lineNumber, $fileName );
}
# }}}
# sub printExpressionValue   {{{
sub printExpressionValue   {
   my $command = shift;
   $command =~ /^printExpressionValue:(.+)$/o;
   my $expressionToPrint = $1;

   sendToVim( $debugger->printExpressionValue( $expressionToPrint ) );
}
# }}}
# sub command   {{{
sub command {
   my $command = shift;
   $command =~ /^command:(.+)$/o;
   $command = $1;

   sendToVim( $debugger->command( $command ) );
}
# }}}
# sub restart   {{{
sub restart   {
   $debugger->restart();
   sendToVim( $debuggerReady );
}
# }}}
# sub quit   {{{
# clean stuff up, and exit
sub quit   {
   $quitting = 1;

   $debugger->quit();

   exit();
}
# }}}
# sub _kill {{{
# clean stuff up, and exit
sub _kill   {
   $quitting = 1;

   $debugger->_kill();

   exit();
}
# }}}



# vim: set ts=3 foldmethod=marker:
