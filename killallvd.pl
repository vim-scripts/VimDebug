#!/usr/bin/perl -w
#
# killallvd.pl
# killall Vim Debugger
#
#
#
# (c) eric johnson 09.31.2002
# distribution under the GPL
#
# email: vimDebug at iijo dot org
# http://iijo.org
#
# $Id: killallvd.pl,v 1.1 2003/06/02 20:29:56 eric Exp eric $

use strict;


`echo "vimDebug has a death wish" >> .vddTOvim`;
`killall -s INT vdd.pl`;
