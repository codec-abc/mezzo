(*****************************************************************************)
(*  Mezzo, a programming language based on permissions                       *)
(*  Copyright (C) 2011, 2012 Jonathan Protzenko and François Pottier         *)
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

(** This module sets up a lexer and a parser to create an AST. *)

type run_options = {
  html_errors: bool;
  backtraces: bool;
}

(** Last directory included has higher precedence. *)
val add_include_dir: string -> unit

(** For the -print-config option. *)
val print_include_dirs: unit -> string

(** [process] doesn't catch exceptions. This is useful for tests that want to
    assert that a test program failed in a certain way. *)
val process: string -> TypeCore.env

(** [run] runs the specified function and prints any error that may pop up. *)
val run: run_options -> (unit -> 'a) -> 'a

(** [print_signature] prints out (in order, and in a fancy manner) the types that have been
   found in the file. *)
val print_signature: Buffer.t -> TypeCore.env -> unit

(** [interpret] is a driver for the interpreter. It evaluates the
    specified file, as well as the files that it depends upon, in
    an appropriate order. *)
val interpret: string -> unit

val lex_and_parse_raw: Ulexing.lexbuf ->
  string -> (Grammar.token, 'a) MenhirLib.Convert.traditional -> 'a

val check_implementation: Module.name -> SurfaceSyntax.implementation ->
  SurfaceSyntax.interface option -> TypeCore.env
