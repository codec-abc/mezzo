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

(** This module provide a convenient way to print a typing derivation into a
 * (supposedly) human-readable form. *)

open TypeCore

val print_derivation : Derivations.derivation -> MzPprint.document
val pderivation : Buffer.t -> Derivations.derivation -> unit
val print_short : Derivations.derivation -> MzPprint.document
val pshort : Buffer.t -> Derivations.derivation -> unit
val print_summary : env -> var -> MzPprint.document
val psummary : Buffer.t -> env * var -> unit
