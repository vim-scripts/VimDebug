" vimDebug.vim
"
"
"
" (c) eric johnson 09.31.2002
" distribution under the GPL
"
" email: vimDebug at iijo dot org
" http://iijo.org
"
" $Id: vimDebug.vim,v 1.9 2003/06/02 20:31:12 eric Exp eric $
"



"""" [BEGIN] stuff you may want to configure """""""""""""""""""""""""""""""""""

" key bindings
map <F12>      :call DBGRstartVimDebuggerDaemon( ' ' )<cr>   " start debugger
map <Leader>s/ :DBGRstartVDD

map <F6>       :call DBGRnext()<CR>
map <F7>       :call DBGRstep()<CR>
map <F8>       :call DBGRcont()<CR>                          " continue

map <Leader>b  :call DBGRsetBreakPoint()<CR>
map <Leader>c  :call DBGRclearBreakPoint()<CR>

map <Leader>v/ :DBGRprintExpression
map <Leader>v  :DBGRprintExpression2 expand( "<cWORD>" )<CR> " print value
                                                             " of WORD under
                                                             " the cursor

map <Leader>/  :DBGRcommand

map <F10>      :call DBGRrestart()<CR>
map <F11>      :call DBGRquit()<CR>


com! -nargs=* DBGRstartVDD call DBGRstartVimDebuggerDaemon( <f-args> )

com! -nargs=* DBGRprintExpression  call DBGRprintExpressionValue( <f-args> )
com! -nargs=1 DBGRprintExpression2 call DBGRprintExpressionValue( <args> )

com! -nargs=* DBGRprintExpression call DBGRprintExpressionValue( <f-args> )

com! -nargs=* DBGRcommand call DBGRcommand( <f-args> )


" colors and symbols
hi currentLine term=reverse cterm=reverse gui=reverse
hi breakPoint  term=NONE    cterm=NONE    gui=NONE
hi empty       term=NONE    cterm=NONE    gui=NONE

sign define currentLine linehl=currentLine
sign define breakPoint  linehl=breakPoint  text=>>
sign define both        linehl=currentLine text=>>
sign define empty       linehl=empty


"""" [END]   stuff you may want to configure """""""""""""""""""""""""""""""""""



" global variables   {{{

let g:vimDebugRunning = "0"

let s:FROMvdd = ".vddTOvim"      " fifo to read  from vdd
let s:TOvdd   = ".vimTOvdd"      " fifo to write to   vdd

let s:APP_EXITED        = "oops" " the application being debugged finished

let s:JDB               = 0      " we are using jdb

let s:lineNumber        = 0
let s:fileName          = ""
let s:bufNr             = 0
let s:programTerminated = 0


" note that this isn't really an array.  its a string.  different values are
" separated by s:sep.  maninpulation of the array is done with the multivalue
" array library:
" http://vim.sourceforge.net/script.php?script_id=171
"
let s:sep              = "-"                       " array separator
let s:breakPointArray  = ""

" }}}



"""" debugger functions """"""""""""""""""""""""""""""""""""""""""""""""""""""""

" function! DBGRstartVimDebuggerDaemon( ... ) {{{
function! DBGRstartVimDebuggerDaemon( ... )
   if g:vimDebugRunning == "1"
      echo 'the debugger is already running'
      return
   endif

   if DBGRfifosExist()
      return
   endif

   let l:fileName = bufname( "%" )

   " decide which debugger to use
   let l:debugger = DBGRgetDebuggerName( fileName )
   if l:debugger == "none"
      return
   endif

   " invoke the debugger
   if a:0 > 0

      " build command
      let l:i = 1
      let l:cmd = "vdd.pl " . l:debugger . " " . l:fileName
      while l:i <= a:0
         exe 'let l:cmd = l:cmd . " " . a:' . l:i . '"'
         let l:i = l:i + 1
      endwhile

      exec "silent :! " . l:cmd . '&'
   else
      let l:cmd = "vdd.pl " . l:debugger . " " . l:fileName
      exec "silent :! " . l:cmd . '&'
   endif

   " loop until vdd says the debugger is done loading
   echo "starting the debugger..."
   while !filewritable( s:FROMvdd )
      continue
   endwhile
   let l:debuggerReady = system( 'cat ' . s:FROMvdd )

   " play with signs
   sign unplace *
   exe "sign place 1 line=1 name=empty file=" . l:fileName

   if has("autocmd")
     autocmd VimLeave * call DBGRquit()
   endif

   " don't run more than one debugger per vim session
   let g:vimDebugRunning = "1"

   :redraw!
   echo 'started the debugger'
endfun!
" }}}

" function! DBGRnext() {{{
function! DBGRnext()
   if g:vimDebugRunning == "0"
      echo "the debugger is not running"
      return
   elseif s:programTerminated
      echo "the application being debugged terminated."
      return
   endif

   " call system( 'echo "next" >> ' . s:TOvdd )     " send message to vdd
   silent exe "redir >> " . s:TOvdd . '| echon "next" | redir END'

   call DBGRhandleLineInfoFromDebugger()
endfun!
" }}}
" function! DBGRstep() {{{
function! DBGRstep()
   if g:vimDebugRunning == "0"
      echo "the debugger is not running"
      return
   elseif s:programTerminated
      echo "the application being debugged terminated."
      return
   endif

   call system( 'echo "step" >> ' . s:TOvdd )     " send message to vdd

   call DBGRhandleLineInfoFromDebugger()
endfun!
" }}}
" function! DBGRcont() {{{
function! DBGRcont()
   if g:vimDebugRunning == "0"
      echo "the debugger is not running"
      return
   elseif s:programTerminated
      echo "the application being debugged terminated."
      return
   endif

   call system( 'echo "cont" >> ' . s:TOvdd )     " send message to vdd

   call DBGRhandleLineInfoFromDebugger()
endfun!
" }}}

" function! DBGRsetBreakPoint() {{{
" see the DBGRclearBreakPoint() comment
function! DBGRsetBreakPoint()
   if g:vimDebugRunning == "0"
      echo "the debugger is not running"
      return
   elseif s:programTerminated
      echo "the application being debugged terminated."
      return
   endif


   let l:currFileName = bufname( "%" )
   let l:bufNr        = bufnr( "%" )
   let l:currLineNr   = line( "." )
   let l:id           = l:bufNr . l:currLineNr


   " check if a breakPoint sign is already placed
   if MvContainsElement( s:breakPointArray, s:sep, l:id ) == 1
      echo "breakpoint already set"
      return
   endif


   " tell the debugger about the new break point
   "call system( 'echo "break:' . l:currLineNr . ':' . l:currFileName . '" >> ' . s:TOvdd )
   silent exe "redir >> " . s:TOvdd . '| echon "break:' . l:currLineNr . ':' . l:currFileName . '" | redir END'


   let s:breakPointArray = MvAddElement( s:breakPointArray, s:sep, l:id )

   " check if a currentLine sign is already placed
   if( s:lineNumber == l:currLineNr )
      exe "sign unplace " . l:id

      exe "sign place " . l:id . " line=" . l:currLineNr .                                                       " name=both file=" . l:currFileName
   else
      exe "sign place " . l:id . " line=" . l:currLineNr .                                                       " name=breakPoint file=" . l:currFileName
   endif


   echo 'breakpoint set'
endfun!
" }}}
" function! DBGRclearBreakPoint() {{{
" a note about signs:
"
" there should only be one sign per line because vim only shows the first sign
" anyway.
"
" a sign with the name currentLine indicates what line the debugger is at
" a sign with the name breakPoint indicates where breakPoints are set
" a sign with the name both should occur when the debugger has stepped to a
" line with a breakPoint
"
" breakPoint sign ids are calculated so that the id =  l:bufNr . l:currLineNr
"
function! DBGRclearBreakPoint()
   if g:vimDebugRunning == "0"
      echo "the debugger is not running"
      return
   elseif s:programTerminated
      echo "the application being debugged terminated."
      return
   endif


   let l:currFileName = bufname( "%" )
   let l:bufNr        = bufnr( "%" )
   let l:currLineNr   = line( "." )
   let l:id           = l:bufNr . l:currLineNr


   " check if a breakPoint sign has really been placed here
   if MvContainsElement( s:breakPointArray, s:sep, l:id ) == 0
      echo "no breakpoint set here"
      return
   endif


   " tell the debugger about the deleted break point
   "call system( 'echo "clearBreakPoint:' . l:currLineNr . ':' . l:currFileName . '" >> ' . s:TOvdd )
   silent exe "redir >> " . s:TOvdd . '| echon "clearBreakPoint:' . l:currLineNr . ':' . l:currFileName . '" | redir END'


   let s:breakPointArray = MvRemoveElement( s:breakPointArray, s:sep, l:id )
   exe "sign unplace " . l:id

   " place a currentLine sign if this is the currentLine
   if( s:lineNumber == l:currLineNr )
      exe "sign place " . l:id . " line=" . l:currLineNr .                                                       " name=currentLine file=" . l:currFileName
   endif


   echo 'breakpoint disabled'
endfun!
" }}}

" function! DBGRprintExpressionValue( ... ) {{{
function! DBGRprintExpressionValue( ... )
   if g:vimDebugRunning == "0"
      echo "the debugger is not running"
      return
   elseif s:programTerminated
      echo "the application being debugged terminated."
      return
   endif

   echo ""

   if a:0 > 0
      " build command
      let l:i = 1
      let l:expression = ""
      while l:i <= a:0
         exe 'let l:expression = l:expression . " " . a:' . l:i . '"'
         let l:i = l:i + 1
      endwhile

      call system( "echo 'printExpressionValue:" . l:expression . "' >> " . s:TOvdd )

      let l:expressionValue = system( 'cat ' . s:FROMvdd )
      echo l:expressionValue
   endif

endfun!
" }}}
" function! DBGRcommand( ... ) {{{
function! DBGRcommand( ... )
   if g:vimDebugRunning == "0"
      echo "the debugger is not running"
      return
   elseif s:programTerminated
      echo "the application being debugged terminated."
      return
   endif

   echo ""

   if a:0 > 0
      " build command
      let l:i = 1
      let l:command = ""
      while l:i <= a:0
         exe 'let l:command = l:command . " " . a:' . l:i . '"'
         let l:i = l:i + 1
      endwhile

      " issue command to debugger
      call system( "echo 'command:" . l:command . "' >> " . s:TOvdd )

      call DBGRhandleCmdResult()
   endif

endfun!
" }}}

" function! DBGRrestart() {{{
function! DBGRrestart()
   if g:vimDebugRunning == "0"
      echo "the debugger is not running"
      return
   endif


   call system( 'echo "restart" >> ' . s:TOvdd )      " send message to vdd

   echo "restarting..."
   let l:debuggerReady = system( 'cat ' . s:FROMvdd ) " blocks until vdd says
                                                      " the debugger is done
                                                      " restarting

   call DBGRunplaceTheLastCurrentLineSign()


   let s:programTerminated = 0

   :redraw!
   echo "restarted."

endfun!
" }}}
" function! DBGRquit() {{{
function! DBGRquit()
   sign unplace *

   if g:vimDebugRunning == "0"
      echo "the debugger is not running"
      return
   endif

   call system( 'echo "quit" >> ' . s:TOvdd )

   if has("autocmd")
     autocmd VimLeave * call DBGRquit()
   endif

   " reset global variables
   let g:vimDebugRunning = "0"

   " reset script variables
   let s:lineNumber        = 0
   let s:fileName          = ""
   let s:bufNr             = 0
   let s:programTerminated = 0
   let s:breakPointArray   = ""
   let s:JDB = 0


   :redraw!
   echo "exited debugger."
endfun!
" }}}



"""" utility functions """""""""""""""""""""""""""""""""""""""""""""""""""""""""

" function! DBGRfifosExist() {{{
" if any of these fifos exist, return TRUE, else return FALSE
" if these fifos exist its probably because vimDebug crashed at some point
" and left these files lying around or because there is more than one vim
" session which isn't currently allowed.
function! DBGRfifosExist()
   let l:FROMvim  = ".vimTOvdd"   " fifo to read from VIM
   let l:TOvim    = ".vddTOvim"   " fifo to write to VIM
   let l:FROMdbgr = ".dbgrTOvdd"  " fifo to read from dbgr
   let l:TOdbgr   = ".vddTOdbgr"  " fifo to write to dbgr

   while 1

      let l:fileName = "scoobydoobydoo"
      if filewritable( l:FROMvim )
         let l:fileName = l:FROMvim
      elseif filewritable( l:TOvim )
         let l:fileName = l:TOvim
      elseif filewritable( l:FROMdbgr )
         let l:fileName = l:FROMdbgr
      elseif filewritable( l:TOdbgr )
         let l:fileName = l:TOdbgr
      endif

      if l:fileName != "scoobydoobydoo"
         let l:choice = confirm( "\nonly one vimDebug session can run at a time.\n\n" . l:fileName . " already exists.\n\neither another instance of vimDebug is running or vimDebug crashed at some\npoint and left this file lying around.\n\nif no other vimDebug sessions are running, just delete\n" . l:fileName . "\n", "&delete\n&cancel", 1 )
         if l:choice == 1
            call delete( l:fileName )
            continue
         elseif l:choice == 2
            return 1
         endif
      endif

      return 0

   endwhile



endfun!
" }}}
" function! DBGRgetDebuggerName( )   {{{
" determine which debugger to invoke from the file extension
"
" parameters
"    fileName
" returns debugger name or 'none' if there isn't a debugger available for
" that particular file extension.  (l:debugger is expected to match up
" with a perl class.  so, for example, if 'Jdb' is returned, there is
" hopefully a Jdb.pm out there somewhere where vdd.pl can find it.
function! DBGRgetDebuggerName( fileName )

   let l:fileExtension = DBGRgetFileExtension( a:fileName )

   if l:fileExtension == ".pl"
      let l:debugger = "PerlDebugger"
      return l:debugger
   elseif l:fileExtension == ".c" || l:fileExtension == ".cpp"
      let l:debugger = "Gdb"
      return l:debugger
   elseif l:fileExtension == ".py"
      let l:debugger = "Pdb"
      return "Pdb"
   elseif l:fileExtension == ".java"
      let l:debugger = "Jdb"
      let s:JDB = 1
      return l:debugger
   else
      echo 'there is no debugger associated with this file type'
      return "none"
   endif

endfun!
" }}}
" function! DBGRgetFileExtension( path ) {{{
" can vim do this for me?  i wish it would
function! DBGRgetFileExtension( path )
   let l:temp = substitute( a:path, '\(^.*\/\)', "", "" ) " path
   let l:temp = substitute( l:temp, '^\.\+', "", "" )    " dot files
   let l:temp = matchstr( l:temp, '\..*$' )              " get extension
   let l:temp = substitute( l:temp, '^\..*\.', '.', '' ) " remove > 1 extensions
   return l:temp
endfun!
" }}}

" function! DBGRhandleLineInfoFromDebugger() {{{
"
" gets the debugger output
"
" if the output == s:APP_EXITED, the program being has terminated so
" DBGRhandlProgramTermination() is called
"
" otherwise, the debugger output is assumed to be in the format:
"     lineNumber:fileName
" call DBGRdoCurrentLineMagicStuff( )
"
" returns nothing
function! DBGRhandleLineInfoFromDebugger()

   " get command results from the debugger
   let l:dbgrOutput = system( 'cat ' . s:FROMvdd )


   if l:dbgrOutput == s:APP_EXITED
      " the debugged program finished terminating
      call DBGRhandleProgramTermination()
      return
   elseif match( l:dbgrOutput, 'vimDebug has a death wish' ) != -1
      " someone ran the killallvd.pl script
      call DBGRquit()
      return
   endif

   call DBGRdoCurrentLineMagicStuff( l:dbgrOutput )
endfun!
" }}}
" function! DBGRhandleCmdResult() {{{
"
" gets debugger output
"
" when the user issues a command via DBGRcommand() the output can be
" anything.
"
" if the output matches l:LINE_INFO, then we should assume that a:cmdResult
" contains line number information and that the user must have issued a
" command like step or next.  in this situation l:cmdResult will have the
" following format:
"    l:LINE_INFO . 'lineNumber:fileName'
" in this case, l:cmdResult is handled the same way DBGRstep() would handle
" the situation.  ie, by calling DBGRdoCurrentlLineMagicStuff()
"
" if the output == s:APP_EXITED, the program being has terminated so
" DBGRhandlProgramTermination() is called
"
" otherwise, just echo the debugger's output
"
" returns nothing
function! DBGRhandleCmdResult()

   let l:LINE_INFO = 'vimDebug:'


   " get command results from the debugger
   let l:cmdResult = system( 'cat ' . s:FROMvdd )


   if match( l:cmdResult, '^' . l:LINE_INFO . '\d\+:.*$' ) != -1

      let l:cmdResult = substitute( l:cmdResult, '^' . l:LINE_INFO, "", "" )
      call DBGRdoCurrentLineMagicStuff( l:cmdResult )

   elseif l:cmdResult == s:APP_EXITED

      call DBGRhandleProgramTermination()
      return

   else
      echo l:cmdResult
   endif

endfun!
" }}}

" function! DBGRdoCurrentLineMagicStuff( lineInfo ) {{{
" gets lineNumber / fileName from the debugger
" jumps to the lineNumber in the file, fileName
" highlights the current line
"
" parameters
"    lineInfo: a string with the format 'lineNumber:fileName'
" returns nothing
function! DBGRdoCurrentLineMagicStuff( lineInfo )

   let l:lineNumber = substitute( a:lineInfo, "\:.*$", "", "" )
   let l:fileName   = substitute( a:lineInfo, "^\\d\\+\:", "", "" )


   let l:fileName = DBGRjumpToLine( l:lineNumber, l:fileName )

   " if there haven't been any signs placed in this file yet, place one
   " the user can't see on line 1 just to shift everything over.
   " otherwise, the code will shift left when the old currentline sign
   " is unplaced and then shift right again when the new currentline sign
   " is placed.  and thats really annoying for the user.
   if bufname( "%" ) != l:fileName
      exe "sign place 1 line=1 name=empty file=" . l:fileName
   endif

   " unplace the old currentline sign
   call DBGRunplaceTheLastCurrentLineSign()

   " place the new currentline sign
   call DBGRplaceCurrentLineSign( l:lineNumber, l:fileName )

   " set script variables for next time
   let s:lineNumber = l:lineNumber
   let s:fileName   = l:fileName
endfun!
" }}}
" function! DBGRjumpToLine( lineNumber, fileName ) {{{
" parameters
"    lineNumber
"    fileName
" returns a fileName.  becuase the fileName may have been changed if jdb
" is being used (see comments in code)
function! DBGRjumpToLine( lineNumber, fileName )

   let l:fileName = a:fileName


   " no buffer with this file has been loaded
   if !bufexists( bufname( l:fileName ) )

      " arrrrg!  jdb gives us a class instead of a fileName.  vdd is giving us
      " a l:fileName that is className.java.  its problematic, but lets assume
      " the className is also the name of the source file.
      if s:JDB == 1
        " open the file wherever it is -- its gotta be in the set path vim
        " option though.
         exe ":find! " . l:fileName
      else
         exe ":e! " . l:fileName
      endif

   endif
"   let l:fileName = bufname( "%" )

   " jump to line a:lineNumber in file a:fileName

   " make a:fileName the current buffer
   if bufname( l:fileName ) != bufname( "%" )
      exe ":buffer " . bufnr( l:fileName )
   endif

   " jump to line
   exe ":"    . a:lineNumber


   return bufname( l:fileName )

endfun!
" }}}
" function! DBGRunplaceTheLastCurrentLineSign() {{{
function! DBGRunplaceTheLastCurrentLineSign()
   let l:lastId = s:bufNr . s:lineNumber

   exe 'sign unplace ' . l:lastId

   " check if there was a break point at l:lastId
   if MvContainsElement( s:breakPointArray, s:sep, l:lastId ) == 1
      exe "sign place " . l:lastId .                                                      " line=" . s:lineNumber . " name=breakPoint file=" . s:fileName
   endif

endfun!
" }}}
" function! DBGRplaceCurrentLineSign( lineNumber, fileName ) {{{
" parameters
"    lineNumber
"    fileName
" returns nothing
function! DBGRplaceCurrentLineSign( lineNumber, fileName )

   " place the new currentline sign
   let l:bufNr = bufnr( a:fileName )
   let l:id    = l:bufNr . a:lineNumber

   if MvContainsElement( s:breakPointArray, s:sep, l:id ) == 1
      exe "sign place " . l:id .
        \ " line=" . a:lineNumber . " name=both file=" . a:fileName
   else
      exe "sign place " . l:id .
        \ " line=" . a:lineNumber . " name=currentLine file=" . a:fileName
   endif


   " set script variables for next time
   let s:bufNr      = l:bufNr

endfun!
" }}}

" function! DBGRhandleProgramTermination() {{{
"
" if the program being debugged has terminated, this function turns off the
" currentline sign but leaves the breakpoint signs on.
"
" sets s:programTerminated = 1.  so the only functions we should be calling
" after this situation is DBGRquit() or DBGRrestart().
function! DBGRhandleProgramTermination()

   call DBGRunplaceTheLastCurrentLineSign()

   " reset script variables
   let s:lineNumber        = 0
   let s:fileName          = ""
   let s:bufNr             = 0
   let s:programTerminated = 1


   echo "application terminated"
endfun!
" }}}





" vim: set ts=3 foldmethod=marker:
