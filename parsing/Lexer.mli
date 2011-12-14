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

(** The lexer for HaMLeT. *)

type error =
  | UnexpectedEndOfComment
  | UnterminatedComment
  | GeneralError of string

exception LexingError of error

val init: string -> unit
val token: Ulexing.lexbuf -> Lexing.position * Grammar.token * Lexing.position

val print_error: Buffer.t -> (Ulexing.lexbuf * error) -> unit
val print_position: Buffer.t -> Ulexing.lexbuf -> unit
