(*****************************************************************************)
(*  HaMLet, a ML dialect with a type-and-capability system                   *)
(*  Copyright (C) 2011 François Pottier, Jonathan Protzenko                  *)
(*                                                                           *)
(*  This program is free software: you can redistribute it and/or modify     *)
(*  it under the terms of the GNU General Public License as published by     *)
(*  the Free Software Foundation, either version 3 of the License, or        *)
(*  (at your option) any later version.                                      *)
(*                                                                           *)
(*  This program is distributed in the hope that it will be useful,          *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(*  GNU General Public License for more details.                             *)
(*                                                                           *)
(*  You should have received a copy of the GNU General Public License        *)
(*  along with this program.  If not, see <http://www.gnu.org/licenses/>.    *)
(*                                                                           *)
(*****************************************************************************)

open Ulexing
open Grammar

(* Position handling *)

let pos_fname = ref "<dummy>"
let pos_lnum = ref 1
let pos_bol = ref 0
let pos pos_cnum =
  let open Lexing in {
    pos_fname = !pos_fname;
    pos_lnum = !pos_lnum;
    pos_bol = !pos_bol;
    pos_cnum;
  }

let init file_name =
  pos_fname := file_name;
  pos_lnum := 1;
  pos_bol := 0

let start_pos lexbuf = pos (lexeme_start lexbuf)
let end_pos lexbuf = pos (lexeme_end lexbuf)

let locate lexbuf token =
  (token, start_pos lexbuf, end_pos lexbuf)

let break_line lexbuf =
  pos_lnum := !pos_lnum + 1;
  pos_bol := lexeme_end lexbuf

let print_position buf lexbuf =
  let open Lexing in
  let start_pos = start_pos lexbuf in
  let end_pos = end_pos lexbuf in
  let filename = start_pos.pos_fname in
  let line = start_pos.pos_lnum in
  let start_col = start_pos.pos_cnum - start_pos.pos_bol in
  let end_col = end_pos.pos_cnum - end_pos.pos_bol in
  Printf.bprintf buf "File \"%s\", line %i, characters %i-%i:"
    filename line start_col end_col

(* Error handling *)

type error =
  | UnexpectedEndOfComment
  | UnterminatedComment
  | GeneralError of string

exception LexingError of error

let raise_error x =
  raise (LexingError x)

let print_error buf (lexbuf, error) =
  match error with
    | UnexpectedEndOfComment ->
        Printf.bprintf buf "%a\nUnexpected end of comment" print_position lexbuf
    | UnterminatedComment ->
        Printf.bprintf buf "%a\nUnterminated comment" print_position lexbuf
    | GeneralError e ->
        Printf.bprintf buf "%a\nLexing error: %s" print_position lexbuf e

(* Various regexps *)

let regexp whitespace = ['\t' ' ']+
let regexp linebreak = ['\n' '\r' "\r\n"]
let regexp low_greek = [945-969]
let regexp up_greek = [913-937]
let regexp greek = low_greek | up_greek
let regexp low_alpha = ['a'-'z']
let regexp up_alpha =  ['A'-'Z']
let regexp alpha = low_alpha | up_alpha
let regexp alpha_greek = alpha | greek
let regexp digit = ['0'-'9']
let regexp int = digit+
let regexp lid =
  (low_alpha | low_greek) alpha_greek* (['_' '\''] | alpha_greek | digit)*
let regexp uid =
  (up_alpha | up_greek) alpha_greek* (['_' '\''] | alpha_greek | digit)*

(* The lexer *)

let rec token = lexer
| linebreak -> break_line lexbuf; token lexbuf
| whitespace -> token lexbuf
| "(*" -> comment 0 lexbuf
| "*)" -> raise_error UnexpectedEndOfComment

(* | "-" -> locate lexbuf MINUS
| "+" -> locate lexbuf PLUS
| "*" -> locate lexbuf AST
| "/" -> locate lexbuf SLASH
| int ->
    let l = utf8_lexeme lexbuf in
    locate lexbuf (INT (int_of_string l))
| "<" | 9001 (* 〈 *) -> locate lexbuf LANGLE
| ">" | 9002 (* 〉 *) -> locate lexbuf RANGLE
| "type" -> locate lexbuf TYPE
| "mu" | 956 (* μ *) -> locate lexbuf MU
| "epsilon" | 949 (* ε *) -> locate lexbuf EPSILON
| "Fun" | 923 (* Λ *) -> locate lexbuf UPLAMBDA
| "case" -> locate lexbuf CASE
| "of" -> locate lexbuf OF
| "switch" -> locate lexbuf SWITCH
| "as" -> locate lexbuf AS
| "unpack" -> locate lexbuf UNPACK
| "pack" -> locate lexbuf PACK
| "=>" | 8658 (* ⇒ *) -> locate lexbuf DBLARROW
| "fun" | 955 (* λ *) -> locate lexbuf FUN
| "forall" | 8704 (* ∀ *) -> locate lexbuf FORALL
| "exists" | 8707 (* ∃ *) -> locate lexbuf EXISTS*)
| "match" -> locate lexbuf MATCH
| "if" -> locate lexbuf IF
| "then" -> locate lexbuf THEN
| "else" -> locate lexbuf ELSE
| "begin" -> locate lexbuf BEGIN
| "end" -> locate lexbuf END
| "with" -> locate lexbuf WITH
| "<-" -> locate lexbuf LARROW
| "." -> locate lexbuf DOT
| "in" -> locate lexbuf IN
| "val" -> locate lexbuf VAL
| "let" -> locate lexbuf LET
| "rec" -> locate lexbuf REC
| "and" -> locate lexbuf AND

| "permission" -> locate lexbuf PERMISSION
| "unknown" -> locate lexbuf UNKNOWN
| "dynamic" -> locate lexbuf DYNAMIC
| "data" -> locate lexbuf DATA
| "exclusive" -> locate lexbuf EXCLUSIVE
| "|" -> locate lexbuf BAR

| "[" -> locate lexbuf LBRACKET
| "]" -> locate lexbuf RBRACKET
| "{" -> locate lexbuf LBRACE
| "}" -> locate lexbuf RBRACE
| "(" -> locate lexbuf LPAREN
| ")" -> locate lexbuf RPAREN

| "," -> locate lexbuf COMMA
| ":" -> locate lexbuf COLON
| "::" -> locate lexbuf COLONCOLON
| ";;" -> locate lexbuf SEMISEMI
| ";" -> locate lexbuf SEMI
| "->" | 8594 (* → *) -> locate lexbuf ARROW
| "*" | 9733 (* ★ *) -> locate lexbuf STAR
| "=" -> locate lexbuf EQUAL
| "consumes" -> locate lexbuf CONSUMES

| lid -> locate lexbuf (LIDENT (utf8_lexeme lexbuf))
| uid -> locate lexbuf (UIDENT (utf8_lexeme lexbuf))
| eof -> locate lexbuf EOF
| _ ->
    raise_error (GeneralError (utf8_lexeme lexbuf))

and comment level = lexer
| "(*" ->
    comment (level+1) lexbuf
| "*)" ->
    assert (level >= 0);
    if level >=1 then
      comment (level-1) lexbuf
    else
      token lexbuf
| linebreak ->
    break_line lexbuf;
    comment level lexbuf
| eof ->
    raise_error UnterminatedComment
| _ ->
    comment level lexbuf


