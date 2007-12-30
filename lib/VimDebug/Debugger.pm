# Debugger
#
# programmatic interface to vimDebug.  extend this class if you wish
# to add a debugger to vimDebug's repertoire.
#
# (c) eric johnson 2002-3090
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: Debugger.pm 93 2007-12-22 21:05:20Z eric $


package VimDebug::Debugger;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(
   $COMPILER_ERROR
   $RUNTIME_ERROR
   $APP_EXITED
   $LINE_INFO
   $DBGR_READY
   $TIME
   $DEBUG
);

use strict;
use vars qw(
   $COMPILER_ERROR
   $RUNTIME_ERROR
   $APP_EXITED
   $LINE_INFO
   $DBGR_READY
   $TIME

   $unix

   $DEBUG
);


$VimDebug::Debugger::VERSION = "1.00";

# when the user issues a command via command() the output can be anything.  if
# the output looks like it contains line number information (ie the user must
# have issued a command like step or next), then return the line number
# information in the following format:
#
#     $LINE_INFO . "lineNumber:fileName"
#
# vimDebug.vim will then recognize that line number information by matching the
# $LINE_INFO string.  (see the DBGRcommand() function in vimDebug.vim)
$LINE_INFO      = "vimDebug:";
$COMPILER_ERROR = "compiler error";
$RUNTIME_ERROR  = "runtime error";
$APP_EXITED     = "application exited";
$DBGR_READY     = "debugger ready";
$TIME           = 5;
$DEBUG          = 0;



# class stuff

sub new {
   my $class = shift;
   my $self = {};
   bless $self, $class;
   return $self;
}


# api to be implented in subclasses

# parameters
#    $path:               path to the debugger
#    @commandLineOptions: command line options for the debugger
# returns $APP_EXITED     if the program being debugged terminated
# returns $COMPILER_ERROR if there was a compiler error
# returns $RUNTIME_ERROR  if there was a runtime  error
# returns "${LINE_INFO}lineNumber:fileName" if possible
# returns $DBGR_READY otherwise
sub startDebugger {}

# no parameters
# returns $APP_EXITED     if the program being debugged terminated
# returns $RUNTIME_ERROR  if there was a runtime  error
# returns "${LINE_INFO}lineNumber:fileName" otherwise
sub next {}

# no parameters
# returns $APP_EXITED     if the program being debugged terminated
# returns $RUNTIME_ERROR  if there was a runtime  error
# returns "${LINE_INFO}lineNumber:fileName" otherwise
sub step {}

# parameters
# returns $APP_EXITED     if the program being debugged terminated
# returns $RUNTIME_ERROR  if there was a runtime  error
# returns "${LINE_INFO}lineNumber:fileName" otherwise
sub cont {}

# parameters
#    $self
#    $lineNumber
#    $fileName
# returns $DBGR_READY
sub setBreakPoint {}

# parameters
#    $self
#    $lineNumber
#    $fileName
# returns $DBGR_READY
sub clearBreakPoint {}

# parameters
#    $self
#    $expression
# returns value of $expression
sub printExpression {}

# evaluates an arbitrary debugger command
# parameters
#    $self
#    $command
#
# returns $APP_EXITED     if the program being debugged terminated
# returns $COMPILER_ERROR if there was a compiler error
# returns $RUNTIME_ERROR  if there was a runtime  error
# returns "${LINE_INFO}lineNumber:fileName" if possible
# returns the debugger's output from executing $command otherwise
sub command {}

# parameters
# returns $APP_EXITED     if the program being debugged terminated
# returns $COMPILER_ERROR if there was a compiler error
# returns $RUNTIME_ERROR  if there was a runtime  error
# returns "${LINE_INFO}lineNumber:fileName" if possible
# returns $DBGR_READY otherwise
sub restart {}

# no parameters
# returns $APP_EXITED
sub quit {}


# utility methods

# these methods are provided for the developer's convenience.  overide them
# if you like.  note that they (hopefully) are written to be platform
# independent


1;
