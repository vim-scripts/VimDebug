#
# Debugger
#
#
# programmatic interface to vimDebug.  extend this class if you wish
# to add a debugger to vimDebug's repertoire.
#
#
#
# TODO
# - make the utility functions platform independent
#
#
# (c) eric johnson 09.31.2002
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: VimDebug.pm 27 2005-03-19 18:02:00Z eric $


package Debugger;

use strict;

use vars qw(
             $TOdbgr
             $FROMdbgr

             $READ
             $WRITE
             $WORKER_RDR
             $WORKER_WTR

             $APP_EXITED
             $LINE_INFO

             $unix

             $PID

             $DEBUG
           );





# global variables {{{

$DEBUG = 0;

$TOdbgr =   ".vddTOdbgr";       # fifo to write to debugger
$FROMdbgr = ".dbgrTOvdd";       # fifo to read from debugger

$APP_EXITED  = "oops";      # the application being debugged finished

$LINE_INFO   = "vimDebug:"; # when the user issues a command via command()
                            # the output can be anything.  if the output looks
                            # like it contains line number information (ie
                            # the user must have issued a command like step or
                            # next), then return the line number information
                            # in the following format:
                            #    $LINE_INFO . "lineNumber:fileName"
                            # vimDebug.vim will then recognize that it line
                            # number information by matching the $LINE_INFO
                            # string.  (see the DBGRcommand() function in
                            # vimDebug.vim)

# }}}




### stuff ######################################################################

# sub new   {{{
sub new   {
   my $class = shift;
   $unix = shift or 1;

   my $self = {};
   bless $self, $class;
   return $self;
}
# }}}
# sub DESTROY   {{{
sub DESTROY   {
   # close and unlink pipes
   close $TOdbgr;
   close $FROMdbgr;

   unlink $TOdbgr;
   unlink $FROMdbgr;
}
# }}}
# sub END  {{{
sub END  {
   DESTROY;
}
# }}}



### callback stubs #############################################################

# read the DEVELOPER.HOWTO file for more extensive documentation on these
# functions.
#
# new debugger interfaces should inherit from Debugger and will therefore
# inherit these subroutines.
#
# the following "virtual" subroutines can be defined by a debugger interface.
# most of them should be redefined by the new debugger interface, but
# initialize() and _kill() are probably fine as is.  note that unless specified
# otherwise, the api mostly defines empty, non-functional default versions of
# these methods.
#
# these subroutines will be called by vdd at appropriate points.
#
# "_next()" and "_kill()" are named funny because "next" and "kill" are perl
# keywords


# parameters
#    $self
# returns nothing
sub initialize   {
   prepareStreams();
}
# parameters
#    $self
#    $sourcePath: file name of the current buffer in vim
#    @commandLineOptions: command line options that should be passed on to the
#                         debugger
# returns nothing
sub startDebugger   {}
# when this function ends, the background debugger process should be ready
# to accept any command, like step, cont, or setBreakPoint.
#
# if it is not an interpreted language, you may need to create a breakpoint on
# line 1 and then issue a run type command to start debugging.  it will then
# stop on the breakpoint on line 1 and be ready for commands like step() or
# _next.
#
# parameters
#    $self
#    $sourcePath: file name of the current buffer in vim
# returns nothing
sub findFirstPrompt   {}

# no parameters
# return $APP_EXITED if the program being debugged terminated
# else, return "lineNumber:fileName"
sub _next   {}
# no parameters
# return $APP_EXITED if the program being debugged terminated
# else, return "lineNumber:fileName"
sub step   {}
# parameters
# return $APP_EXITED if the program being debugged terminated
# else, return "lineNumber:fileName"
sub cont   {}
# parameters
#    $self
#    $lineNumber
#    $fileName
# returns nothing
sub setBreakPoint   {}
# parameters
#    $self
#    $lineNumber
#    $fileName
# returns nothing
sub clearBreakPoint   {}

# parameters
#    $self
#    $expression
# returns value of $expression
sub printExpressionValue   {}

# evaluates an arbitrary debugger command
# parameters
#    $self
#    $command
#
# return $APP_EXITED if the program being debugged terminated.
#
# if the output looks like it contains line number information (ie the user
# must have issued a command like step or next), then return the line number
# information in the following format:
#    $LINE_INFO . "lineNumber:fileName"
#  vimDebug.vim will then recognize that it line number information by matching
#  the $LINE_INFO string.  (see the DBGRcommand() function in vimDebug.vim)
#
# otherwise, return the debugger's output from executing $command.
sub command   {}

# parameters
# returns nothing
sub restart   {}
# no parameters
# returns nothing
sub quit   {}
# no parameters
# returns nothing
sub _kill   {
   kill( 15, $PID );
   kill(  9, $PID );  # i should check status of process first
}





### utility methods ############################################################

# these methods are provided for the developer's convenience.  overide them
# if you like.  note that they (hopefully) are written to be platform
# independent


# sub prepareStreams {{{
# read the ARCHITECTURE file and possibly the DEVELOPER.HOWTO file for more
# information about whats going on here
#
# parameters: none
# returns:    nothing
sub prepareStreams()
{
   pipe( $WORKER_RDR, $WRITE );   # setup pipes for communication
   pipe( $READ, $WORKER_WTR );    # setup pipes for communication
   select( $WRITE );      $| = 1; # make unbuffered
   select( $WORKER_WTR ); $| = 1; # make unbuffered
   select( STDOUT );      $| = 1; # make unbuffered
}
# }}}
# sub createDebuggerProcess {{{
# forks and execs the debugger process
# redirects STDOUT and STDIN of the debugger process so the parent can
# read and write to the child through pipes created in prepareStreams()
#
# parameters
#    $self
#    @debuggerInvocationIncantation: a list that gets passed to exec
# returns nothing
sub createDebuggerProcess()
{
   my $self = shift or die "createDebuggerProcess() requires 2 parameters";
   my @debuggerInvocationIncantation = @_ or
                       die "createDebuggerProcess() requires 2 parameters";


   die "cannot fork" unless( defined( $PID = fork ) );

   if( $PID == 0 )   {

      close $READ; close $WRITE; # debugger does not need them

      open( STDOUT, ">&" . fileno($WORKER_WTR) ) || die "Can't redirect stdout";
      open( STDERR, ">&" . fileno($WORKER_WTR) ) || die "Can't redirect stderr";
      open( STDIN,  "<&" . fileno($WORKER_RDR) ) || die "Can't redirect stdin";

      # start debugger
      exec( @debuggerInvocationIncantation )
         or die "debugger won't start. is the debugger in your path?";

   }

   close $WORKER_RDR; close $WORKER_WTR; # vdd does not need them any more
}
# }}}
# sub getUntilPrompt {{{
# reads from $Debugger::READ until it finds $dbgrPrompt.  the regex match
# is performed against on one line of $Debugger::READ output at a time, not
# against all the output.
#
# this method is not now, but should one day be platform independent.  a line
# is defined differently on different operating systems.  for example, on unix,
# a line ends with a "\n", and on windows a line ends with a "???".
#
# parameters
#    $self
#    $dbgrPrompt: a string or regex
# returns debugger output in the form of a list (@debuggerOutput)
sub getUntilPrompt   {
   my $self       = shift or die "getUntilPrompt() requires 2 parameters";
   my $dbgrPrompt = shift or die "getUntilPrompt() requires 2 parameters";


   my $line = "";
   my @debuggerOutput = $line;
   my $prompt = "";


   while( 1 )   {

      my $char = getc( $READ );
      print $char if( $DEBUG );
      $prompt .= $char;

      if( Utils->unix() )   {
         if( $char eq "\n" )   {  # this doesn't look real portable
            $prompt =~ s///go;  # not sure why the heck these show up or
                                    # what they are, but you gotta remove
                                    # those control Z's.

            push( @debuggerOutput, $prompt );
            $prompt = "";
            next;
         }
      }
      elsif( Utils->dos() )   {
         die "not yet implemented for microsoft environments";
      }

      # found the prompt; stop looping
      if( $prompt =~ /$dbgrPrompt/ )   {
         push( @debuggerOutput, $prompt );
         return @debuggerOutput
      }
   }
}
# }}}
# sub removeFileExtension {{{
# takes in a fileName and removes the file extension.
#
# parameters
#    $self
#    $fileName: a file name that may or may not also have a path.
#               example: '/path/foo/fileName' or 'fileName'
# returns ( $path, $fileName )
sub removeFileExtension {
   my $self     = shift or die "removeFileExtension() requires 2 parameters";
   my $fileName = shift or die "removeFileExtension() requires 2 parameters";

   $fileName =~ s/^(.+)\..*$/$1/o;
   return $fileName;
}
# }}}



1;
# vim: set ts=3 foldmethod=marker:
