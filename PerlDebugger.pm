# PerlDebugger.pm
#
# perl debugger interface for vimDebug
#
#
#
# (c) eric johnson 10.28.2002
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: PerlDebugger.pm,v 1.14 2003/06/02 20:26:15 eric Exp eric $


package PerlDebugger;

use IPC::Open2;
use Debugger;

@ISA = qw( Debugger );

use strict;
use vars qw(
             $debuggerPath
             $debuggerPrompt

             $LINEINFO

             $DEBUG
                               );


### set some global variables ##################################################

$DEBUG = 0;

$debuggerPath   = "perl";
$debuggerPrompt = '  DB<+\d+>+ $';






### callback functions implemented #############################################

# sub startDebugger   {{{
sub startDebugger   {
   my $self               = shift;
   my $path               = shift;
   my @commandLineOptions = @_;


   # this makes the perl debugger print to STDOUT instead of the tty (i think).
   open( OUT, ">.perldb" ) or die "couldn't create .perldb";
   print OUT '
      open( my $oldOut, ">&STDOUT" );
      open( my $oldIn, "<&STDIN" );

      sub afterinit   {
         open( $DB::OUT, ">&", $oldOut );
         open( $DB::IN, "<&", $oldIn );
      }';
   close OUT;
   chmod 0600, ".perldb";


   # these are environment variables that control how the perl debugger behaves
   #$ENV{"PERL5DB"} = 'BEGIN { require "perl5db.pl"; }';
   $ENV{"PERLDB_OPTS"} = "ReadLine=0 ornaments=0 LineInfo=$Debugger::FROMdbgr";


   unlink $Debugger::FROMdbgr; # the perl debugger crashes (loops forever) if
                               # this file exists when the debugger starts or
                               # restarts


   # build command to start the debugger
   my @debuggerIncantation = $debuggerPath;
   push( @debuggerIncantation, "-d" );
   push( @debuggerIncantation, $path );
   push( @debuggerIncantation, @commandLineOptions );

   $self->createDebuggerProcess( @debuggerIncantation );
}
# }}}
# sub findFirstPrompt   {{{
sub findFirstPrompt   {
   my $self = shift;


   until( -e $Debugger::FROMdbgr )   {
      next;
   }

   open( $LINEINFO, "< $Debugger::FROMdbgr" )
      or die "file won't open for read: $Debugger::FROMdbgr";

   select( $Debugger::READ );  $| = 1;    # make unbuffered
   select( STDOUT );

   $self->getUntilPrompt( $debuggerPrompt );
   $self->getLineInfo();
}
# }}}
# sub _next   {{{
# "_next()" is named funny because "next" is a perl keyword
sub _next   {
   my $self = shift;


   print $Debugger::WRITE "n\n";

   my @dbgrOutput = $self->getUntilPrompt( $debuggerPrompt );
   if( $self->applicationExited( @dbgrOutput ) )   {
      return $Debugger::APP_EXITED;
   }
   else   {
      return $self->getLineInfo();
   }
}
# }}}
# sub step   {{{
sub step   {
   my $self = shift;


   print $Debugger::WRITE "s\n";

   my @dbgrOutput = $self->getUntilPrompt( $debuggerPrompt );
   if( $self->applicationExited( @dbgrOutput ) )   {
      return $Debugger::APP_EXITED;
   }
   else   {
      return $self->getLineInfo();
   }
}
# }}}
# sub cont   {{{
sub cont   {
   my $self = shift;


   print $Debugger::WRITE "c\n";

   my @dbgrOutput = $self->getUntilPrompt( $debuggerPrompt );
   if( $self->applicationExited( @dbgrOutput ) )   {
      return $Debugger::APP_EXITED;
   }
   else   {
      return $self->getLineInfo();
   }
}
# }}}
# sub setBreakPoint   {{{
sub setBreakPoint   {
   my $self       = shift;
   my $lineNumber = shift;
   my $fileName   = shift;


   # set the file
   print $Debugger::WRITE "f $fileName\n";
   $self->getUntilPrompt( $debuggerPrompt );

   # set the line number
   print $Debugger::WRITE "b $lineNumber\n";
   $self->getUntilPrompt( $debuggerPrompt );
}
# }}}
# sub clearBreakPoint   {{{
sub clearBreakPoint   {
   my $self       = shift;
   my $lineNumber = shift;
   my $fileName   = shift;


   # set the file
   print $Debugger::WRITE "f $fileName\n";
   $self->getUntilPrompt( $debuggerPrompt );

   # set the line number
   print $Debugger::WRITE "B $lineNumber\n";
   $self->getUntilPrompt( $debuggerPrompt );
}
# }}}
# sub printExpressionValue   {{{
sub printExpressionValue   {
   my $self = shift;
   my $expression = shift;

   print $Debugger::WRITE "p $expression\n";
   return $self->getExpressionValue( $self->getUntilPrompt( $debuggerPrompt ) );
}
# }}}
# sub command   {{{
sub command   {
   my $self = shift;
   my $command = shift;


   print $Debugger::WRITE "$command\n";

   my @dbgrOutput = $self->getUntilPrompt( $debuggerPrompt );
   if( $self->isAnEmptyLine( @dbgrOutput ) )   {
      return $Debugger::LINE_INFO . $self->getLineInfo( @dbgrOutput );
   }
   else   {
      return join( '', removePrompt( @dbgrOutput ) );
   }
}
# }}}
# sub restart   {{{
sub restart   {
   my $self = shift;

   unlink $Debugger::FROMdbgr; # the perl debugger crashes (loops forever) if
                               # this file exists when the debugger starts or
                               # restarts

   print $Debugger::WRITE "R\n";

   $self->findFirstPrompt();
}
# }}}
# sub quit   {{{
sub quit   {
   print $Debugger::WRITE "q\n";
   close( $Debugger::READ );
   close( $Debugger::WRITE );
   unlink $Debugger::FROMdbgr;
   unlink ".perldb";
}
# }}}





### other functions ############################################################

# sub removePrompt   {{{
# removes the last line from the debugger output.
# the last line is the prompt
sub removePrompt   {
   my $self = shift;
   my @debuggerOutput = @_;

   pop( @debuggerOutput );

   return @debuggerOutput;
}
# }}}
# sub isAnEmptyLine   {{{
# parameters
#    $self
#    @debuggerOutput
# returns 0 if the debugger output was just a prompt
# returns 1 if the debugger output included anything other than a prompt.
sub isAnEmptyLine   {
   my $self = shift;
   my @debuggerOutput = @_;


   @debuggerOutput = removePrompt( @debuggerOutput );

   if( $#debuggerOutput > -1 )   {
      return 0;
   }
   else   {
      return 1;
   }
}
# }}}
# sub applicationExited   {{{
sub applicationExited   {
   my $self = shift;
   my @debuggerOutput = @_;

   foreach my $line ( @debuggerOutput )   {
      chomp( $line );

      next if( $line =~ /$debuggerPrompt/o );

      #$line =~ s///og;  # not sure why the heck these show up or what
                            # they are, but you gotta remove those control Z's.

      if( $line =~ /^Debugged program terminated.  Use q to quit or R to/o )   {
         return 1;
      }
      elsif( $line =~ /^Use \`q\' to quit or \`R\' to restart\.  \`h q\'/o )   {
         return 1;
      }
   }

   return 0;
}
# }}}
# sub getLineInfo   {{{
# not sure why, but $Debugger::getUntilPrompt( $debuggerPrompt )'s getc() call doesn't work on
# the pipe we've opened to read perl debugger output.  but this slurpy
# <$Debugger::READ> method does work.  ...whatever.
#
# prompt should look something like: "  DB<1> "
sub getLineInfo   {
   my $self = shift;


   my $line = <$LINEINFO>;
   chomp( $line );
   print ">>>" . $line . "<<<\n" if $DEBUG;


   # ignore the nested junk the debugger returns when it hits code with an
   # eval() statement
   while( $line =~ /\[.*\]/o )   {
      $line =~ s/^.*\[//;
      $line =~ s/\].*$//;
   }


   if( $line =~ /\/perl5db.pl:/o )   {
      return $Debugger::APP_EXITED;
   }
   elsif( $line =~ /\((.+):(\d+)\):\d+/o )   {
      return "$2:$1";
   }
   elsif( $line =~ /\((.+):(\d+)\)/o )   {
      return "$2:$1";
   }
   elsif( $line =~ /Use \`q\' to quit or \`R\' to restart\.  \`h q\' for/o )   {
      return $Debugger::APP_EXITED;
   }
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

      next                         if( $line =~ /  DB<+\d+>+ /o ); # skip prompt
      return $Debugger::APP_EXITED if( $line =~ /\/perl5db.pl:/o );

      $everythingExceptLinesWithPrompts .= $line;
   }

   return $everythingExceptLinesWithPrompts;
}
# }}}




1;
# vim: set ts=3 foldmethod=marker:
