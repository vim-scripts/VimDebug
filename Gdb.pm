# Gdb.pm
#
# GNU debugger interface for vimDebug
#
#
#
# (c) eric johnson 10.28.2002
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: Gdb.pm,v 1.1 2003/06/02 20:20:40 eric Exp eric $


package Gdb;

use IPC::Open2;
use Debugger;
use Utils;

@ISA = qw( Debugger );

use strict;
use vars qw(
             $debuggerPath
             $debuggerPrompt

             $DEBUG
                               );


### global variables  ##########################################################

$debuggerPath   = "gdb";
$debuggerPrompt = '^\(gdb\) $';

$DEBUG = 1;





### callback functions implemented #############################################

# sub startDebugger   {{{
sub startDebugger   {
   my $self               = shift;
   my $sourceCode         = shift;
   my @commandLineOptions = @_;

   ( my $path, my $fileName ) = Utils->getPathAndFileName( $sourceCode );
   $fileName = $self->removeFileExtension( $fileName );

   # build command to start the debugger
   my @debuggerIncantation = $debuggerPath;
   push( @debuggerIncantation, "-f" );
   push( @debuggerIncantation, "--directory" );
   push( @debuggerIncantation, $path );
   push( @debuggerIncantation, $fileName );
   push( @debuggerIncantation, @commandLineOptions );

   $self->createDebuggerProcess( @debuggerIncantation );
}
# }}}
# sub findFirstPrompt   {{{
sub findFirstPrompt   {
   my $self = shift;
   my $path = shift;

   $self->getUntilPrompt( $debuggerPrompt ); # get initial startup mesg hoohaw
   $self->setBreakPoint( "main", $path );    # set breakpoint in main()
   print $Debugger::WRITE "run\n";
   $self->getUntilPrompt( $debuggerPrompt );
}
# }}}
# sub _next   {{{
# "_next()" is named funny because "next" is a perl keyword
sub _next   {
   my $self = shift;
   print $Debugger::WRITE "n\n";
   return $self->getLineNumberInfo( $self->getUntilPrompt( $debuggerPrompt ) );
}
# }}}
# sub step   {{{
sub step   {
   my $self = shift;
   print $Debugger::WRITE "s\n";
   return $self->getLineNumberInfo( $self->getUntilPrompt( $debuggerPrompt ) );
}
# }}}
# sub setBreakPoint   {{{
sub setBreakPoint   {
   my $self       = shift;
   my $lineNumber = shift;
   my $fileName   = shift;

   # ???????????????????????????????????????
   # ???? uh how do you do this in gdb ?????
   # ???????????????????????????????????????
   # set the file
   # print $Debugger::WRITE "f $fileName\n";
   # $self->getUntilPrompt( $debuggerPrompt );

   # set the line number
   print STDOUT "lineNumber: $lineNumber\n";
   print $Debugger::WRITE "break $lineNumber\n";
   $self->getUntilPrompt( $debuggerPrompt );
}
# }}}
# sub clearBreakPoint   {{{
sub clearBreakPoint   {
   my $self       = shift;
   my $lineNumber = shift;
   my $fileName   = shift;


   # ???????????????????????????????????????
   # ???? uh how do you do this in gdb ?????
   # ???????????????????????????????????????
   # set the file
   #print $Debugger::WRITE "f $fileName\n";
   #$self->getUntilPrompt( $debuggerPrompt );

   # set the line number
   print $Debugger::WRITE "clear $lineNumber\n";
   $self->getUntilPrompt( $debuggerPrompt );
}
# }}}
# sub cont   {{{
sub cont   {
   my $self = shift;
   print $Debugger::WRITE "continue\n";
   return $self->getLineNumberInfo( $self->getUntilPrompt( $debuggerPrompt ) );
}
# }}}
# sub printExpressionValue   {{{
sub printExpressionValue   {
   my $self = shift;
   my $expression = shift;

   print $Debugger::WRITE "print $expression\n";
   return $self->getExpressionValue( $self->getUntilPrompt( $debuggerPrompt ) );
}
# }}}
# sub command   {{{
sub command   {
   my $self = shift;
   my $command = shift;

   print $Debugger::WRITE "$command\n";
   my @debuggerOutput = $self->getUntilPrompt( $debuggerPrompt );
   return $self->parseCommandResults( @debuggerOutput );
}
# }}}
# sub restart   {{{
sub restart   {
   my $self = shift;

   print $Debugger::WRITE "run\n";
   $self->getUntilPrompt( $debuggerPrompt );
}
# }}}
# sub quit   {{{
sub quit   {
   print $Debugger::WRITE "q\n";
   close( $Debugger::READ );
   close( $Debugger::WRITE );
}
# }}}





### other functions ############################################################

# sub parseCommandResults   {{{
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
# returns $Debugger:LINE_INFO . 'lineNumber:fileName' if the information can be
#         found
# otherwise, returns all the output (minus the dbgr prompt) as one string
sub parseCommandResults   {
   my $self = shift;
   my @debuggerOutput = @_;

   my $lineNumberInfo = $Debugger::APP_EXITED;
   foreach my $line ( @debuggerOutput )   {
      chomp( $line );

         $line =~ s///go;  # not sure why the heck these show up or what
                               # they are, but you gotta remove those
                               # control Z's.

      if( $line =~ /(.+):(\d+):\d+:\w+:0x\d+/o )   {
         return $Debugger::LINE_INFO . "$2:$1";
      }
      elsif( $line =~ / in __libc_start_main \(\) from /o )   {
         return $Debugger::APP_EXITED;
      }
      elsif( $line =~ /Program exited with code \d+\./o )   {
         return $Debugger::APP_EXITED;
      }
   }

   pop( @debuggerOutput );
   return join( '', @debuggerOutput );
}
# }}}
# sub getLineNumberInfo   {{{
# parameters
#    $self
#    @debuggerOutput
# returns $Debugger::APP_EXITED if the application being debugged terminated.
# returns lineNumber:fileName if the information can be found
# otherwise, returns all the output (minus the dbgr prompt) as one string
sub getLineNumberInfo   {
   my $self = shift;
   my @debuggerOutput = @_;

   my $lineNumberInfo = $Debugger::APP_EXITED;
   foreach my $line ( @debuggerOutput )   {
      chomp( $line );

         $line =~ s///go;  # not sure why the heck these show up or what
                               # they are, but you gotta remove those
                               # control Z's.

      if( $line =~ /(.+):(\d+):\d+:\w+:0x\d+/o )   {
         return "$2:$1";
      }
      elsif( $line =~ / in __libc_start_main \(\) from /o )   {
         return $Debugger::APP_EXITED;
      }
      elsif( $line =~ /Program exited with code \d+\./o )   {
         return $Debugger::APP_EXITED;
      }
   }

   pop( @debuggerOutput );
   return join( '', @debuggerOutput );
}
# }}}
# sub getExpressionValue   {{{
# gets all the debugger output except lines containing the prompt ( something
# like "  DB<1>" ) and the first line, which is just the print expression
# command that was passed to the the perl debugger.
sub getExpressionValue   {
   shift;
   my @debuggerOutput = @_;

   my $everythingExceptLinesWithPrompts = "";
   foreach my $line ( @debuggerOutput )   {
      chomp( $line );
      $line =~ s///go;  # not sure why the heck these show up or what
                            # they are, but you gotta remove those
                            # control Z's.
      $everythingExceptLinesWithPrompts .= $line;
   }

   $everythingExceptLinesWithPrompts =~ s/\(gdb\) $//o;
   return $everythingExceptLinesWithPrompts;
}
# }}}




1;
# vim: set ts=3 foldmethod=marker:
