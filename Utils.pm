#!/usr/bin/perl -w
#
# Utils.pm
#
# utility functions.
#
# TODO
# - most functions here should be platform independant, but they're not.
#
#
# (c) eric johnson 09.31.2002
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: Utils.pm,v 1.1 2003/06/02 20:29:20 eric Exp eric $

package Utils;

use strict;

use vars qw(
             $unix

             $DEBUG
                               );



# sub getPathAndFileName {{{
# seperate out the path and file name from $file
#
# parameters
#    $file: a file name that may or may not also have a path.
#           example: '/path/foo/fileName' or 'fileName'
# returns ( $path, $fileName )
sub getPathAndFileName {
   my $self = shift;
   my $file = shift;

   if( $file =~ /(^.*\/)(.*)$/ )   {
      return ( $1, $2 );
   }
   else   {
      return ( "", $file );
   }
}
# }}}
# sub makeNamedPipe   {{{
# make a fifo
sub makeNamedPipe   {
   my $self = shift;
   my $fifo = shift or die "gotta pass a fifo to this function";

   # if pipe is already there, die
   if( -p $fifo )   {
      print "$fifo already exists.  perhaps another instance of" .
            " vimDebug is running?\nif not, just delete $fifo.\n";
      exit();
   }

   if( unix() )   {
      if(    system( 'mkfifo', $fifo )
          && system( 'mknod',  $fifo, 'p' ) )   {
         die "is mkfifo or mknod in your path?\n";
      }
   }
   elsif( dos() )   {
      die "not yet implemented for a microsoft operating system\n";
   }
}
# }}}
# sub dos   {{{
# returns true if user is on a microsoft operating system
sub dos   {
   my $self = shift;

   if( $unix )   {
      return 1;
   }
   else   {
      return 0;
   }
}
# }}}
# sub unix   {{{
# returns true if user is on a unix operating system
sub unix   {
   my $self = shift;

   if( $unix )   {
      return 0;
   }
   else   {
      return 1;
   }
}
# }}}


1;
# vim: set ts=3 foldmethod=marker:
