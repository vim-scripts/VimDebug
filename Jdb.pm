# Jdb.pm
#
# Java debugger interface for vimDebug
#
#
# TODO
# -- fix strange bug where the application doesn't step even though it was told
#    to step.
#
# (c) eric johnson 10.28.2002
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: Jdb.pm,v 1.3 2003/06/02 20:22:50 eric Exp eric $


package Jdb;

use IPC::Open2;
use Debugger;
use Utils;

@ISA = qw( Debugger );

use strict;
use vars qw(
             $debuggerPath
             $debuggerPrompt0
             $debuggerPrompt1

             $APP_EXITED

             $sourceCode
             @commandLineOptions

             %breakPoints
                                  );


### set some global variables ##################################################

$debuggerPath    = "jdb";

$debuggerPrompt0 = '^> $';
$debuggerPrompt1 = '(^\w+\[\d+\] $)|(^The application exited$)';

$APP_EXITED      = 0;   # indicates whether the application being debugged
                        # has terminated or not





### callback functions implemented #############################################

# sub startDebugger   {{{
sub startDebugger   {
   my $self            = shift;
   $sourceCode         = shift;
   @commandLineOptions = @_;


   ( my $path, my $fileName ) = Utils->getPathAndFileName( $sourceCode );
   $fileName = $self->removeFileExtension( $fileName );

   # determine classpath
   my $classpath = $ENV{"CLASSPATH"} . ":" . $path;

   # determine sourcepath
   my $sourcepath = $path;
   if( exists( $ENV{"SOURCEPATH"} ) )   {
      $sourcepath = $ENV{"SOURCEPATH"};
   };

   # build command to start the debugger
   my @debuggerIncantation = $debuggerPath;
   push( @debuggerIncantation, "-classpath" );
   push( @debuggerIncantation, $classpath );
   push( @debuggerIncantation, "-sourcepath" );
   push( @debuggerIncantation, $sourcepath );
   push( @debuggerIncantation, $fileName );
   push( @debuggerIncantation, @commandLineOptions );

   $self->createDebuggerProcess( @debuggerIncantation );
}
# }}}
# sub findFirstPrompt   {{{
sub findFirstPrompt   {
   my $self       = shift;
   my $sourceCode = shift;

   ( my $path, my $fileName ) = Utils->getPathAndFileName( $sourceCode );
   my $class = $self->removeFileExtension( $fileName );

   $self->getUntilPrompt( $debuggerPrompt0 );
   print $Debugger::WRITE "stop at $class:1\n";
   $self->getUntilPrompt( $debuggerPrompt0 );
   print $Debugger::WRITE "run\n";
   $self->getUntilPrompt( $debuggerPrompt1 );
   $self->step();
}
# }}}
# sub _next   {{{
# "_next()" is named funny because "next" is a perl keyword
sub _next   {
   my $self = shift;

   print $Debugger::WRITE "next\n";
   my @debuggerOutput = $self->getUntilPrompt( $debuggerPrompt1 );
   return getLineNumberInfo( $self, @debuggerOutput );
}
# }}}
# sub step   {{{
sub step   {
   my $self = shift;

   print $Debugger::WRITE "step\n";
   my @debuggerOutput = $self->getUntilPrompt( $debuggerPrompt1 );
   return getLineNumberInfo( $self, @debuggerOutput );
}
# }}}
# sub cont   {{{
sub cont   {
   my $self = shift;

   print $Debugger::WRITE "cont\n";
   my @debuggerOutput = $self->getUntilPrompt( $debuggerPrompt1 );
   return $self->getLineNumberInfo( @debuggerOutput );
}
# }}}
# sub setBreakPoint   {{{
sub setBreakPoint   {
   my $self = shift;
   my $lineNumber = shift;
   my $sourceCode = shift;


   ( my $path, my $fileName ) = Utils->getPathAndFileName( $sourceCode );
   my $class = $self->removeFileExtension( $fileName );

   # remember break point
   $breakPoints{ "${class}:${lineNumber}" } = [$lineNumber, $sourceCode];

   print $Debugger::WRITE "stop at ${class}:${lineNumber}\n";
   my @debuggerOutput = $self->getUntilPrompt( $debuggerPrompt1 );
   getLineNumberInfo( $self, @debuggerOutput );
}
# }}}
# sub clearBreakPoint   {{{
sub clearBreakPoint   {
   my $self = shift;
   my $lineNumber = shift;
   my $sourceCode = shift;


   ( my $path, my $fileName ) = Utils->getPathAndFileName( $sourceCode );
   my $class = $self->removeFileExtension( $fileName );

   # forget break point
   delete $breakPoints{ "${class}:${lineNumber}" };

   print $Debugger::WRITE "clear ${class}:${lineNumber}\n";
   my @debuggerOutput = $self->getUntilPrompt( $debuggerPrompt1 );
   getLineNumberInfo( $self, @debuggerOutput );
}
# }}}
# sub printExpressionValue   {{{
sub printExpressionValue   {
   my $self = shift;
   my $expression = shift;

   print $Debugger::WRITE "dump $expression\n";
   my @debuggerOutput = $self->getUntilPrompt( $debuggerPrompt1 );
   return getExpressionValue( $self, @debuggerOutput );
}
# }}}
# sub command   {{{
sub command   {
   my $self = shift;
   my $command = shift;

   print $Debugger::WRITE "$command\n";
   my @debuggerOutput = $self->getUntilPrompt( $debuggerPrompt1 );
   my $lineNumberInfo = $self->getLineNumberInfo( @debuggerOutput );
   if( $lineNumberInfo eq $Debugger::APP_EXITED )   {
      return join( '', @debuggerOutput );
   }
   else   {
      return $Debugger::LINE_INFO . $lineNumberInfo;
   }
}
# }}}
# sub restart   {{{
sub restart   {
   my $self = shift;


   # exit jdb

   # the whole jdb process exits when the application being debugged finishes
   # and you can't write to a process that no longer exists.
   if( $APP_EXITED == 0 )   {
      print $Debugger::WRITE "exit\n";
   }
   else  {
      $APP_EXITED = 0;
   }

   # start jdb
   $self->initialize();
   $self->startDebugger( $sourceCode, @commandLineOptions );
   $self->findFirstPrompt( $sourceCode );

   # restore break points
   foreach my $key ( keys %breakPoints )   {
      $self->setBreakPoint( $breakPoints{$key}[0], $breakPoints{$key}[1] );
   }
}
# }}}
# sub quit   {{{
sub quit   {
   print $Debugger::WRITE "exit\n";
}
# }}}





### other functions ############################################################

# sub getUntilPrompt   {{{
sub getUntilPrompt   {
   my $self = shift;
   my $prompt = shift;


   my @debuggerOutput = Debugger->getUntilPrompt( $prompt );

   my $line = pop( @debuggerOutput );
   $APP_EXITED = 1 if( $line =~ /^The application exited$/ );

   return @debuggerOutput;
}
# }}}
# sub getLineNumberInfo   {{{
sub getLineNumberInfo   {
   shift;
   my @debuggerOutput = @_;

   my $lineNumberInfo = $Debugger::APP_EXITED;
   foreach my $line ( @debuggerOutput )   {
      chomp( $line );

      if( $line =~ / \"thread=.*, (.*)\..*, line=(\d+) bci=\d+/o )   {
         $lineNumberInfo = "$2:$1.java";
         last;
      }
      elsif( $line =~ /^The application exited$/ )  {
         return $Debugger::APP_EXITED;
      }
   }

   return $lineNumberInfo;
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

      next if( $line =~ /^> /o );           # skip lines w/prompts
      next if( $line =~ /^\w+\[\d+\] /o );  # skip lines w/prompts

      $everythingExceptLinesWithPrompts .= $line;
   }

   return $everythingExceptLinesWithPrompts;
}
# }}}




1;
# vim: set ts=3 foldmethod=marker:
