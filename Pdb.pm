# Pdb.pm
#
# python debugger interface for vimDebug
#
#
# TODO
# - if the user changed their python prompt, stuff breaks.
#
#
# (c) eric johnson 10.28.2002
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: Pdb.pm,v 1.2 2003/06/02 20:24:50 eric Exp eric $


package Pdb;

use IPC::Open2;
use Debugger;

@ISA = qw( Debugger );

use strict;
use vars qw(
             $dbgrPath
             $dbgrPromptA
             $dbgrPromptB
             $dbgrPromptC
             $dbgrPrompt

             $path
             @commandLineOptions

             %breakPoints
                               );


### set some global variables ##################################################

$dbgrPath = "/usr/lib/python2.2/pdb.py";

$dbgrPromptA  = '^\(Pdb\) $';
$dbgrPromptB  = '^>>> $';
$dbgrPromptC  = '> <string>\(1\)\?\(\)->None';
$dbgrPrompt   = "($dbgrPromptA)|($dbgrPromptB)";



### callback functions implemented #############################################

# sub startDebugger   {{{
sub startDebugger   {
   my $self            = shift;
   $path               = shift;
   @commandLineOptions = @_;


   # build command to start the debugger
   my @debuggerIncantation = "python";
   push( @debuggerIncantation, "-i" );
#   push( @debuggerIncantation, "-c" );
#   push( @debuggerIncantation, "import sys;sys.ps1='>>> '" );
   push( @debuggerIncantation, $dbgrPath );
   push( @debuggerIncantation, $path );
   push( @debuggerIncantation, @commandLineOptions );

   $self->createDebuggerProcess( @debuggerIncantation );
}
# }}}
# sub findFirstPrompt   {{{
sub findFirstPrompt   {
   my $self = shift;

   $self->getUntilPrompt( $dbgrPrompt );
   $self->step();
   $self->step();
}
# }}}
# sub _next   {{{
sub _next   {
   my $self = shift;
   print $Debugger::WRITE "n\n";
   return $self->parseOutput( $self->getUntilPrompt( $dbgrPrompt ) );
}
# }}}
# sub step   {{{
sub step   {
   my $self = shift;
   print $Debugger::WRITE "s\n";
   return $self->parseOutput( $self->getUntilPrompt( $dbgrPrompt ) );
}
# }}}
# sub cont   {{{
sub cont   {
   my $self = shift;
   print $Debugger::WRITE "c\n";
   return $self->parseOutput( $self->getUntilPrompt( $dbgrPrompt ) );
}
# }}}
# sub setBreakPoint   {{{
sub setBreakPoint   {
   my $self       = shift;
   my $lineNumber = shift;
   my $sourceCode = shift;


   ( my $path, my $fileName ) = Utils->getPathAndFileName( $sourceCode );

   # remember break point
   $breakPoints{ "${sourceCode}:${lineNumber}" } = [$lineNumber, $sourceCode];

   print $Debugger::WRITE "b ${fileName}:${lineNumber}\n";
   $self->getUntilPrompt( $dbgrPrompt );
}
# }}}
# sub clearBreakPoint   {{{
sub clearBreakPoint   {
   my $self       = shift;
   my $lineNumber = shift;
   my $sourceCode = shift;


   ( my $path, my $fileName ) = Utils->getPathAndFileName( $sourceCode );

   # forget break point
   delete $breakPoints{ "${sourceCode}:${lineNumber}" };

   print $Debugger::WRITE "clear ${sourceCode}:${lineNumber}\n";
   $self->getUntilPrompt( $dbgrPrompt );
}
# }}}
# sub printExpressionValue   {{{
sub printExpressionValue   {
   my $self = shift;
   my $expression = shift;

   print $Debugger::WRITE "p $expression\n";
   return $self->getExpressionValue( $self->getUntilPrompt( $dbgrPrompt ) );
}
# }}}
# sub command   {{{
sub command   {
   my $self = shift;
   my $command = shift;


   print $Debugger::WRITE "$command\n";
   return $self->parseCommandOutput( $self->getUntilPrompt( $dbgrPrompt ) );
}
# }}}
# sub restart   {{{
sub restart   {
   my $self = shift;

   # exit jdb
   $self->quit();

   # start jdb
   $self->initialize();
   $self->startDebugger( $path, @commandLineOptions );
   $self->findFirstPrompt();

   # restore break points
   foreach my $key ( keys %breakPoints )   {
      $self->setBreakPoint( $breakPoints{$key}[0], $breakPoints{$key}[1] );
   }
}
# }}}
# sub quit   {{{
sub quit   {
   my $self       = shift;

   print $Debugger::WRITE "q\n";
   print $Debugger::WRITE "";
   close( $Debugger::READ );
   close( $Debugger::WRITE );
}
# }}}





### other functions ############################################################

# sub parseOutput   {{{
# parameters
#    $self
#    @debuggerOutput
# returns $Debugger::APP_EXITED if the application being debugged terminated.
# returns lineNumber:fileName if the information can be found
# otherwise, returns all the output (minus the dbgr prompt) as one string
sub parseOutput   {
   my $self = shift;
   my @debuggerOutput = @_;


   foreach my $line ( @debuggerOutput )   {
      chomp( $line );

      next if( $line =~ /$dbgrPromptA/o );

      return $Debugger::APP_EXITED if( $line =~ /$dbgrPromptB/o );
      return $Debugger::APP_EXITED if( $line =~ /$dbgrPromptC/o );
      return "$2:$1" if( $line =~ /\> (.+)\((\d+)\)(\w+|\?+)\(\)/o );

      next if( $line =~ /^\> \<string/o );
   }

   pop( @debuggerOutput );
   return join( '', @debuggerOutput );
}
# }}}
# sub parseCommandOutput   {{{
#
# parse output from command()
#
# this is weird having 2 functions that do almost the same thing.  isn't there
# a better way?
#
# parameters
#    $self
#    @debuggerOutput
# returns $Debugger::APP_EXITED if the application being debugged terminated.
# returns $Debugger::LINE_INFO . 'lineNumber:fileName' if the information can
#         be found
# otherwise, returns all the output (minus the dbgr prompt) as one string
sub parseCommandOutput   {
   my $self = shift;
   my @debuggerOutput = @_;


   foreach my $line ( @debuggerOutput )   {
      chomp( $line );

      next if( $line =~ /$dbgrPromptA/o );

      return $Debugger::APP_EXITED if( $line =~ /$dbgrPromptB/o );
      return $Debugger::APP_EXITED if( $line =~ /$dbgrPromptC/o );
      return $Debugger::LINE_INFO . "$2:$1"
                                if( $line =~ /\> (.+)\((\d+)\)(\w+|\?+)\(\)/o );

      next if( $line =~ /^\> \<string/o );
   }

   pop( @debuggerOutput );
   return join( '', @debuggerOutput );
}
# }}}
# sub getExpressionValue   {{{
# returns all the debugger output except lines containing the prompt
# returns $Debugger::APP_EXITED if the application being debugged terminated.
sub getExpressionValue   {
   shift;
   my @debuggerOutput = @_;

   my $everythingExceptLinesWithPrompts = "";
   foreach my $line ( @debuggerOutput )   {
      chomp( $line );

      next                         if( $line =~ /$dbgrPromptA/o ); # skip prompt
      return $Debugger::APP_EXITED if( $line =~ /$dbgrPromptB/o );
      return $Debugger::APP_EXITED if( $line =~ /$dbgrPromptC/o );

      $everythingExceptLinesWithPrompts .= $line;
   }

   return $everythingExceptLinesWithPrompts;
}
# }}}




1;
# vim: set ts=3 foldmethod=marker:
