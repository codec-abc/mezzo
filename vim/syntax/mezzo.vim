" Vim syntax file
" Language:     Mezzo
" Filenames:    *.mz *.mzi
" Maintainers:  Jonathan Protzenko    <jonathan.protzenko@gmail.com>
" URL:          http://gallium.inria.fr/~protzenk/mezzo-lang/
" Last Change:  2012 Dec 6      First version

" This is based on the original OCaml syntax highlighting file.

if exists("b:current_syntax") && b:current_syntax == "mezzo"
  finish
endif

" mezzo is case sensitive.
syn case match

" lowercase identifier - the standard way to match
syn match    mezzoLCIdentifier /\<\(\l\|_\)\(\w\|'\)*\>/

syn match    mezzoKeyChar    "|"

" Errors
syn match    mezzoBraceErr   "}"
syn match    mezzoBrackErr   "\]"
syn match    mezzoParenErr   ")"
syn match    mezzoArrErr     "|]"

syn match    mezzoCommentErr "\*)"

syn match    mezzoCountErr   "\<downto\>"
syn match    mezzoCountErr   "\<to\>"

syn match    mezzoDoneErr    "\<done\>"
syn match    mezzoThenErr    "\<then\>"
syn match    mezzoEndErr     "\<end\>"

" Some convenient clusters
syn cluster  mezzoAllErrs contains=mezzoBraceErr,mezzoBrackErr,mezzoParenErr,mezzoCommentErr,mezzoCountErr,mezzoDoErr,mezzoDoneErr,mezzoEndErr,mezzoThenErr

syn cluster  mezzoAENoParen contains=mezzoBraceErr,mezzoBrackErr,mezzoCommentErr,mezzoCountErr,mezzoDoErr,mezzoDoneErr,mezzoEndErr,mezzoThenErr

syn cluster  mezzoContained contains=mezzoTodo,mezzoPreDef,mezzoModParam,mezzoModParam1,mezzoPreMPRestr,mezzoMPRestr,mezzoMPRestr1,mezzoMPRestr2,mezzoMPRestr3,mezzoModRHS,mezzoFuncWith,mezzoFuncStruct,mezzoModTypeRestr,mezzoModTRWith,mezzoWith,mezzoWithRest,mezzoModType,mezzoFullMod,mezzoVal


" Enclosing delimiters
syn region   mezzoEncl transparent matchgroup=mezzoKeyword start="(" matchgroup=mezzoKeyword end=")" contains=ALLBUT,@mezzoContained,mezzoParenErr
syn region   mezzoEncl transparent matchgroup=mezzoKeyword start="{" matchgroup=mezzoKeyword end="}"  contains=ALLBUT,@mezzoContained,mezzoBraceErr
syn region   mezzoEncl transparent matchgroup=mezzoKeyword start="\[" matchgroup=mezzoKeyword end="\]" contains=ALLBUT,@mezzoContained,mezzoBrackErr
syn region   mezzoEncl transparent matchgroup=mezzoKeyword start="\[|" matchgroup=mezzoKeyword end="|\]" contains=ALLBUT,@mezzoContained,mezzoArrErr


" Comments
syn region   mezzoComment start="(\*" end="\*)" contains=mezzoComment,mezzoTodo
syn keyword  mezzoTodo contained TODO FIXME XXX NOTE


" Blocks
syn region   mezzoEnd matchgroup=mezzoKeyword start="\<begin\>" matchgroup=mezzoKeyword end="\<end\>" contains=ALLBUT,@mezzoContained,mezzoEndErr

" "if"
syn region   mezzoNone matchgroup=mezzoKeyword start="\<if\>" matchgroup=mezzoKeyword end="\<then\>" contains=ALLBUT,@mezzoContained,mezzoThenErr

" "open"
syn region   mezzoNone matchgroup=mezzoKeyword start="\<open\>" matchgroup=mezzoModule end="\<\(\w\|'\)*\(\.\u\(\w\|'\)*\)*\>" contains=@mezzoAllErrs,mezzoComment

" "include"
syn match    mezzoKeyword "\<include\>" skipwhite skipempty nextgroup=mezzoModParam,mezzoFullMod

" "module" - somewhat complicated stuff ;-)
syn region   mezzoModule matchgroup=mezzoKeyword start="\<module\>" matchgroup=mezzoModule end="\<\u\(\w\|'\)*\>" contains=@mezzoAllErrs,mezzoComment skipwhite skipempty nextgroup=mezzoPreDef
syn region   mezzoPreDef start="."me=e-1 matchgroup=mezzoKeyword end="\l\|=\|)"me=e-1 contained contains=@mezzoAllErrs,mezzoComment,mezzoModParam,mezzoModTypeRestr,mezzoModTRWith nextgroup=mezzoModPreRHS
syn region   mezzoModParam start="([^*]" end=")" contained contains=@mezzoAENoParen,mezzoModParam1,mezzoVal
syn match    mezzoModParam1 "\<\u\(\w\|'\)*\>" contained skipwhite skipempty nextgroup=mezzoPreMPRestr

syn region   mezzoPreMPRestr start="."me=e-1 end=")"me=e-1 contained contains=@mezzoAllErrs,mezzoComment,mezzoMPRestr,mezzoModTypeRestr

syn region   mezzoMPRestr start=":" end="."me=e-1 contained contains=@mezzoComment skipwhite skipempty nextgroup=mezzoMPRestr1,mezzoMPRestr2,mezzoMPRestr3
syn region   mezzoMPRestr1 matchgroup=mezzoModule start="\ssig\s\=" matchgroup=mezzoModule end="\<end\>" contained contains=ALLBUT,@mezzoContained,mezzoEndErr,mezzoModule
syn region   mezzoMPRestr2 start="\sfunctor\(\s\|(\)\="me=e-1 matchgroup=mezzoKeyword end="->" contained contains=@mezzoAllErrs,mezzoComment,mezzoModParam skipwhite skipempty nextgroup=mezzoFuncWith,mezzoMPRestr2
syn match    mezzoMPRestr3 "\w\(\w\|'\)*\(\.\w\(\w\|'\)*\)*" contained
syn match    mezzoModPreRHS "=" contained skipwhite skipempty nextgroup=mezzoModParam,mezzoFullMod
syn keyword  mezzoKeyword val
syn region   mezzoVal matchgroup=mezzoKeyword start="\<val\>" matchgroup=mezzoLCIdentifier end="\<\l\(\w\|'\)*\>" contains=@mezzoAllErrs,mezzoComment skipwhite skipempty nextgroup=mezzoMPRestr
syn region   mezzoModRHS start="." end=".\w\|([^*]"me=e-2 contained contains=mezzoComment skipwhite skipempty nextgroup=mezzoModParam,mezzoFullMod
syn match    mezzoFullMod "\<\u\(\w\|'\)*\(\.\u\(\w\|'\)*\)*" contained skipwhite skipempty nextgroup=mezzoFuncWith

syn region   mezzoFuncWith start="([^*]"me=e-1 end=")" contained contains=mezzoComment,mezzoWith,mezzoFuncStruct skipwhite skipempty nextgroup=mezzoFuncWith
syn region   mezzoFuncStruct matchgroup=mezzoModule start="[^a-zA-Z]struct\>"hs=s+1 matchgroup=mezzoModule end="\<end\>" contains=ALLBUT,@mezzoContained,mezzoEndErr

syn match    mezzoModTypeRestr "\<\w\(\w\|'\)*\(\.\w\(\w\|'\)*\)*\>" contained
syn region   mezzoModTRWith start=":\s*("hs=s+1 end=")" contained contains=@mezzoAENoParen,mezzoWith
syn match    mezzoWith "\<\(\u\(\w\|'\)*\.\)*\w\(\w\|'\)*\>" contained skipwhite skipempty nextgroup=mezzoWithRest
syn region   mezzoWithRest start="[^)]" end=")"me=e-1 contained contains=ALLBUT,@mezzoContained

syn keyword  mezzoKeyword  and as assert class
syn keyword  mezzoKeyword  constraint else
syn keyword  mezzoKeyword  exception external fun

syn keyword  mezzoKeyword  in inherit initializer
syn keyword  mezzoKeyword  land lazy let match
syn keyword  mezzoKeyword  method mutable new of
syn keyword  mezzoKeyword  parser private raise rec
syn keyword  mezzoKeyword  try type
syn keyword  mezzoKeyword  virtual when while with

syn keyword  mezzoKeyword  function

syn keyword  mezzoBoolean  true false
syn match    mezzoKeyChar  "!"

syn keyword  mezzoType     array bool char float
syn keyword  mezzoType     int list option
syn keyword  mezzoType     string unit

syn keyword  mezzoOperator not

syn match    mezzoConstructor  "(\s*)"
syn match    mezzoConstructor  "\[\s*\]"
syn match    mezzoConstructor  "\[|\s*>|]"
syn match    mezzoConstructor  "\[<\s*>\]"
syn match    mezzoConstructor  "\u\(\w\|'\)*\>"
syn match    mezzoConstructor  "\l\(\w\|'\)*::"

syn match    mezzoCharacter    "'\\\d\d\d'\|'\\[\'ntbr]'\|'.'"
syn match    mezzoCharacter    "'\\x\x\x'"
syn match    mezzoCharErr      "'\\\d\d'\|'\\\d'"
syn match    mezzoCharErr      "'\\[^\'ntbr]'"
syn region   mezzoString       start=+"+ skip=+\\\\\|\\"+ end=+"+

syn match    mezzoFunDef       "->"
syn match    mezzoRefAssign    ":="
syn match    mezzoTopStop      ";;"
syn match    mezzoOperator     "\^"
syn match    mezzoOperator     "::"

syn match    mezzoOperator     "&&"
syn match    mezzoOperator     "<"
syn match    mezzoOperator     ">"
syn match    mezzoAnyVar       "\<_\>"
syn match    mezzoKeyChar      "|[^\]]"me=e-1
syn match    mezzoKeyChar      ";"
syn match    mezzoKeyChar      "\~"
syn match    mezzoKeyChar      "?"
syn match    mezzoKeyChar      "\*"
syn match    mezzoKeyChar      "="

syn match    mezzoOperator   "<-"

syn match    mezzoNumber        "\<-\=\d\(_\|\d\)*[l|L|n]\?\>"
syn match    mezzoNumber        "\<-\=0[x|X]\(\x\|_\)\+[l|L|n]\?\>"
syn match    mezzoNumber        "\<-\=0[o|O]\(\o\|_\)\+[l|L|n]\?\>"
syn match    mezzoNumber        "\<-\=0[b|B]\([01]\|_\)\+[l|L|n]\?\>"
syn match    mezzoFloat         "\<-\=\d\(_\|\d\)*\.\?\(_\|\d\)*\([eE][-+]\=\d\(_\|\d\)*\)\=\>"

" Synchronization
syn sync minlines=50
syn sync maxlines=500

syn sync match mezzoEndSync     groupthere mezzoEnd     "\<end\>"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_mezzo_syntax_inits")
  if version < 508
    let did_mezzo_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink mezzoBraceErr     Error
  HiLink mezzoBrackErr     Error
  HiLink mezzoParenErr     Error
  HiLink mezzoArrErr       Error

  HiLink mezzoCommentErr   Error

  HiLink mezzoCountErr     Error
  HiLink mezzoDoErr        Error
  HiLink mezzoDoneErr      Error
  HiLink mezzoEndErr       Error
  HiLink mezzoThenErr      Error

  HiLink mezzoCharErr      Error

  HiLink mezzoErr          Error

  HiLink mezzoComment      Comment

  HiLink mezzoModPath      Include
  HiLink mezzoObject       Include
  HiLink mezzoModule       Include
  HiLink mezzoModParam1    Include
  HiLink mezzoModType      Include
  HiLink mezzoMPRestr3     Include
  HiLink mezzoFullMod      Include
  HiLink mezzoModTypeRestr Include
  HiLink mezzoWith         Include
  HiLink mezzoMTDef        Include

  HiLink mezzoScript       Include

  HiLink mezzoConstructor  Constant

  HiLink mezzoVal          Keyword
  HiLink mezzoModPreRHS    Keyword
  HiLink mezzoMPRestr2     Keyword
  HiLink mezzoKeyword      Keyword
  HiLink mezzoMethod       Include
  HiLink mezzoFunDef       Keyword
  HiLink mezzoRefAssign    Keyword
  HiLink mezzoKeyChar      Keyword
  HiLink mezzoAnyVar       Keyword
  HiLink mezzoTopStop      Keyword
  HiLink mezzoOperator     Keyword

  HiLink mezzoBoolean      Boolean
  HiLink mezzoCharacter    Character
  HiLink mezzoNumber       Number
  HiLink mezzoFloat        Float
  HiLink mezzoString       String

  HiLink mezzoLabel        Identifier

  HiLink mezzoType         Type

  HiLink mezzoTodo         Todo

  HiLink mezzoEncl         Keyword

  delcommand HiLink
endif

let b:current_syntax = "mezzo"

" vim: ts=8
