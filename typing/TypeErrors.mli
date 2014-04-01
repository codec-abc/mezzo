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

(** Everything you ever dreamed of for reporting errors. *)

open Kind
open TypeCore

(** Clients of this module will want to use the various errors offered. *)
type raw_error =
  | CyclicDependency of Module.name
  | NotAFunction of var
  | ExpectedType of typ * var * Derivations.derivation
  | ExpectedPermission of typ * Derivations.derivation
  | RecursiveOnlyForFunctions
  | MissingField of Field.name
  | ExtraField of Field.name
  | NoSuchField of var * Field.name
  | CantAssignTag of var
  | NoSuchFieldInPattern of ExpressionsCore.pattern * Field.name
  | BadPattern of ExpressionsCore.pattern * var
  | BadField of Datacon.name * Field.name
  | NoTwoConstructors of var
  | MatchBadDatacon of var * Datacon.name
  | MatchBadTuple of var
  | AssignNotExclusive of typ * Datacon.name
  | FieldCountMismatch of typ * Datacon.name
  | NoMultipleArguments
  | ResourceAllocationConflict of var
  | UncertainMerge of var
  | ConflictingTypeAnnotations of typ * typ
  | IllKindedTypeApplication of ExpressionsCore.tapp * kind * kind
  | BadTypeApplication of var
  | NonExclusiveAdoptee of typ
  | NoAdoptsClause of var
  | NotDynamic of var
  | NoSuitableTypeForAdopts of var * typ
  | AdoptsNoAnnotation
  | NotMergingClauses of env * typ * typ * env * typ * typ
  | NoSuchTypeInSignature of var * typ * Derivations.derivation
  | DataTypeMismatchInSignature of Variable.name * string
  | VarianceAnnotationMismatch
  | ExportNotDuplicable of Variable.name
  | LocalType
  | Instantiated of Variable.name * typ
  | PackWithExists
  | SeveralWorkingFunctionTypes of var

(** Set up the module to take into account the warn / error / silent settings
 * specified on the command-line. *)
val parse_warn_error: string -> unit

(** This function raises an exception that will be later on catched in
 * {!Driver}. *)
val raise_error : env -> raw_error -> 'a

(** This function may raise an exception that will be later on catched in
 * {!Driver}, or emit a warning, or do nothing, depending on whether the error
 * has been tweaked with the warn/error string. *)
val may_raise_error : env -> raw_error -> unit

(** A {!raw_error} is wrapped. *)
type error

(** And this is the exception that you can catch. *)
exception TypeCheckerError of error

(** Once an exception is catched, it can be printed with {!Log.error} and
 * [%a]... *)
val print_error : Buffer.t -> error -> unit

(** ... or displayed as an HTML error. *)
val html_error: error -> unit

(**/**)

val internal_extracterror: error -> raw_error
