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

(** Unified error handling *)

open TypeCore
open Types
open Expressions
open DerivationPrinter

type error = env * raw_error

and raw_error =
  | CyclicDependency of Module.name
  | NotAFunction of var
  | HasFlexible of typ
  | ExpectedType of typ * var * Derivations.derivation
  | RecursiveOnlyForFunctions
  | MissingField of Field.name
  | ExtraField of Field.name
  | NoSuchField of var * Field.name
  | CantAssignTag of var
  | NoSuchFieldInPattern of pattern * Field.name
  | BadPattern of pattern * var
  | BadField of Datacon.name * Field.name
  | SubPattern of pattern
  | NoTwoConstructors of var
  | MatchBadDatacon of var * Datacon.name
  | MatchBadTuple of var
  | NoSuchPermission of typ
  | AssignNotExclusive of typ * Datacon.name
  | FieldCountMismatch of typ * Datacon.name
  | NoMultipleArguments
  | ResourceAllocationConflict of var
  | UncertainMerge of var
  | ConflictingTypeAnnotations of typ * typ
  | IllKindedTypeApplication of tapp * kind * kind
  | BadTypeApplication of var
  | PolymorphicFunctionCall
  | BadFactForAdoptedType of var * typ * Fact.fact
  | NoAdoptsClause of var
  | NotDynamic of var
  | NoSuitableTypeForAdopts of var * typ
  | AdoptsNoAnnotation
  | NotMergingClauses of env * typ * typ * env * typ * typ
  | MissingFieldInSignature of Variable.name
  | NoSuchTypeInSignature of var * typ
  | DataTypeMismatchInSignature of Variable.name * string
  | NotExclusiveOwns of var
  | VarianceAnnotationMismatch

exception TypeCheckerError of error

let raise_error env e =
  raise (TypeCheckerError (env, e))
;;

(* -------------------------------------------------------------------------- *)

(* For pretty-printing. *)

exception NotFoldable

(** [fold_var env var] tries to find (hopefully) one "main" type for [var], by
    folding back its "main" type [t] into a form that's suitable for one
    thing, and one thing only: printing. *)
let rec fold_var (env: env) (depth: int) (var: var): (env * typ) option =
  if is_flexible env var || depth > 5 then raise NotFoldable;

  let perms = get_permissions env var in
  let perms = List.filter
    (function
      | TySingleton (TyOpen p) when same env p var ->
          false
      | TyUnknown ->
          false
      | _ ->
          true
    ) perms
  in
  match perms with
  | [] ->
      Some (env, TyUnknown)
  | t :: []
  | TyDynamic :: t :: []
  | t :: TyDynamic :: [] ->
      begin try
        let env, t = fold_type env (depth + 1) t in
        let env = set_permissions env var [TyDynamic] in
        Some (env, t)
      with NotFoldable ->
        None
      end
  | _ ->
      None


and fold_type (env: env) (depth: int) (t: typ): env * typ =
  if depth > 5 then
    raise NotFoldable;

  match t with
  | TyUnknown
  | TyDynamic ->
      env, t

  | TyBound _ ->
      Log.error "All types should've been opened at that stage"

  | TyOpen _ ->
      env, t

  | TyForall _
  | TyExists _
  | TyApp _ ->
      env, t

  | TySingleton (TyOpen p) ->
      begin match fold_var env (depth + 1) p with
      | Some t ->
          t
      | None ->
          raise NotFoldable
      end

  | TyTuple components ->
      let env, components =
        List.fold_left (fun (env, cs) t ->
          let env, t = fold_type env (depth + 1) t in
          env, t :: cs
        ) (env, []) components
      in
      let components = List.rev components in
      env, TyTuple components

  | TyAnd (c, t) ->
      let env, t = fold_type env (depth + 1) t in
      env, TyAnd (c, t)

  | TyConcreteUnfolded branch ->
      let env, branch = fold_branch env (depth + 1) branch in
      env, TyConcreteUnfolded branch

  | TySingleton _ ->
      env, t

  | TyArrow _ ->
      env, t

  | TyBar (t, p) ->
      let env, t = fold_type env (depth + 1) t in
      env, TyBar (t, p)

  | TyAnchoredPermission (x, t) ->
      let env, t = fold_type env (depth + 1) t in
      env, TyAnchoredPermission (x, t)

  | TyEmpty ->
      env, t

  | TyStar _ ->
      Log.error "Huh I don't think we should have that here"

and fold_branch env depth branch =
  let env, fields =
    List.fold_left (fun (env, fields) -> function
      | FieldPermission p ->
          let env, p = fold_type env depth p in
          env, FieldPermission p :: fields
      | FieldValue (n, t) ->
          let env, t = fold_type env depth t in
          env, FieldValue (n, t) :: fields
    ) (env, []) branch.branch_fields in
  let branch_fields = List.rev fields in
  let env, branch_adopts = fold_type env depth branch.branch_adopts in
  let branch = { branch with
    branch_fields;
    branch_adopts;
  } in
  env, branch
;;

let fold_type env t =
  try
    let _, t = fold_type env 0 t in
    Some t
  with NotFoldable ->
    None
;;

let fold_var env t =
  Option.map snd (fold_var env 0 t)
;;

(* -------------------------------------------------------------------------- *)

(* The main error printing function. *)

open TypePrinter
open ExprPrinter

let print_error buf (env, raw_error) =
  let bprintf s = Printf.bprintf buf s in
  (* Extra verbose debugging output. *)
  if Log.debug_level () >= 5 then begin
    bprintf "\nOH NOES. Printing permissions.\n\n%a" pdoc (print_permissions, env);
    bprintf "\nError message follows.\n\n";
  end;
  (* A few error messages are printed *without* an error location. *)
  begin match raw_error with
    | CyclicDependency _ ->
        ()
    | _ ->
      Lexer.p buf (location env)    
  end;
  (* Now, print an error-specific message. *)
  match raw_error with
  | CyclicDependency m ->
      (* TEMPORARY cyclic dependencies are hard to understand, so
	 showing the cycle in a more explicit manner would be useful *)
      bprintf "There is a cyclic dependency on module %a" Module.p m
  | NotAFunction p ->
      begin match fold_var env p with
      | Some t ->
          bprintf
            "%a is not a function, it has type:\n%a"
            pname (env, p)
            ptype (env, t)
      | None ->
          bprintf
            "%a is not a function, the only permissions available for it are:\n%a"
            pname (env, p)
            ppermission_list (env, p)
      end
  | NoSuchPermission t ->
      bprintf
        "Unable to extract the following permission:\n%a"
        ptype (env, t);
  | HasFlexible t ->
      bprintf
        "The following type still contains flexible variables:\n%a"
        ptype (env, t);
  | ExpectedType (t, var, d) ->
      bprintf
        "Could not extract from this subexpression (named %a) the following type:\n%a\n\
          some explanations follow:\n%a"
        pnames (env, get_names env var)
        ptype (env, t)
        pderivation d
  | RecursiveOnlyForFunctions ->
      bprintf
        "Recursive definitions are enabled for functions only"
  | MissingField f ->
      bprintf
        "Field %a is missing in that constructor"
        Field.p f
  | ExtraField f ->
      bprintf
        "Field %a is superfluous in that constructor"
        Field.p f
  | NoTwoConstructors var ->
      begin match fold_var env var with
      | Some t ->
          bprintf
            "%a has type:\n%a\nIt is not a type with two constructors"
            pname (env, var)
            ptype (env, t)
      | None ->
          bprintf
            "%a has no suitable permission for a type with two constructors;\n\
              the only permissions available for it are:\n%a"
            pname (env, var)
            ppermission_list (env, var)
      end
  | NoSuchField (var, f) ->
      begin match fold_var env var with
      | Some t ->
          bprintf
            "%a has type:\n%a\nThere is no field named %a"
            pname (env, var)
            ptype (env, t)
            Field.p f
      | None ->
          bprintf
            "%a has no suitable permission with field %a;\n\
             the only permissions available for it are:\n%a"
            pname (env, var)
            Field.p f
            ppermission_list (env, var)
      end
  | CantAssignTag var ->
      begin match fold_var env var with
      | Some t ->
          bprintf
            "%a has type:\n%a\nWe can't assign a tag to it"
            pname (env, var)
            ptype (env, t)
      | None ->
          bprintf
            "%a has no suitable permission that would accept a tag update, \
              the only permissions available for it are:\n%a"
            pname (env, var)
            ppermission_list (env, var)
      end
  | SubPattern pat ->
      bprintf
        "There is a sub-constraint in that pattern, not allowed: %a"
        ppat (env, pat)
  | MatchBadTuple p ->
      bprintf
        "Trying to match a tuple against a var whose only \
          permissions are:\n%a"
        ppermission_list (env, p)
  | MatchBadDatacon (p, datacon) ->
      bprintf
        "Trying to match data constructor %a against a var whose only \
          permissions are:\n%a"
        Datacon.p datacon
        ppermission_list (env, p)
  | NoSuchFieldInPattern (pat, field) ->
      bprintf
        "The pattern %a mentions field %a which is unknown for that branch"
        ppat (env, pat)
        Field.p field
  | BadPattern (pat, var) ->
      bprintf
        "Cannot match pattern %a against %a, the only permissions available for it are:\n%a"
        ppat (env, pat)
        pname (env, var)
        ppermission_list (env, var)
  | BadField (datacon, name) ->
      bprintf "This pattern mentions field %a but data constructor \
          %a has no such field"
        Field.p name
        Datacon.p datacon
  | AssignNotExclusive (t, datacon) ->
      bprintf
        "This value has type %a: constructor %a belongs to a data type that \
          is not defined as exclusive"
        ptype (env, t)
        Datacon.p datacon
  | FieldCountMismatch (t, datacon) ->
      bprintf
        "This value has type %a: constructor %a belongs to a data type that \
          does not have the same number of fields"
        ptype (env, t)
        Datacon.p datacon
  | NoMultipleArguments ->
      bprintf
        "Functions take only one (tuple) argument"
  | ResourceAllocationConflict var ->
      bprintf "Exclusive resource allocation conflict on %a"
        pnames (env, get_names env var);
  | UncertainMerge var ->
      bprintf "Merging distinct constructors into a nominal \
          type with type parameters, results are unpredictable, you should \
          consider providing annotations for %a"
        pnames (env, get_names env var)
  | ConflictingTypeAnnotations (t1, t2) ->
      bprintf "The context provides a type annotation, namely %a \
        but here is a type annotation, namely %a, that is conflicting the \
        context-provided type annotation"
        ptype (env, t1)
        ptype (env, t2);
  | BadTypeApplication var ->
      bprintf "Var %a does not have a polymorphic type, the only \
          permissions available for it are %a"
        pnames (env, get_names env var)
        ppermission_list (env, var)
  | IllKindedTypeApplication (t, k, k') ->
      bprintf "While applying type %a: this type has kind %a but \
          the sub-expression has a polymorphic type with kind %a"
        pdoc ((fun t -> ExprPrinter.print_tapp env t), t)
        pdoc (print_kind, k) 
        pdoc (print_kind, k');
  | PolymorphicFunctionCall ->
      bprintf "This is a polymorphic function call, results are \
          undefined; consider using a type application"
  | BadFactForAdoptedType (p, t, f) ->
      bprintf "Type %a cannot adopt type %a because it is not \
          marked as exclusive but %a"
        pnames (env, get_names env p)
        ptype (env, t)
        pfact f
  | NoAdoptsClause p ->
      bprintf "Trying to give/take to/from %a but this expression \
          cannot adopt; the only permissions available for it are %a"
        pnames (env, get_names env p)
        ppermission_list (env, p)
  | NotDynamic p ->
      bprintf "Cannot take %a as it is not dynamic, the only \
          permissions available for it are %a"
        pnames (env, get_names env p)
        ppermission_list (env, p)
  | NoSuitableTypeForAdopts (p, t) ->
      bprintf "Trying to give/take %a to/from some expression, but \
          the expression adopts %a and the only permissions available for %a are %a"
        pnames (env, get_names env p)
        ptype (env, t)
        pnames (env, get_names env p)
        ppermission_list (env, p)
  | AdoptsNoAnnotation ->
      bprintf "In this “give e1 to e2” statement, please provide a \
          type annotation for e1"
  | NotMergingClauses (left_env, left_var, left_t, right_env, right_var, right_t) ->
      bprintf "While merging %a and %a, it turns out they have \
          different adopts clauses, namely %a and %a; I refuse to merge these, \
          so please annotate using identical adopts clauses"
        ptype (left_env, left_var)
        ptype (right_env, right_var)
        ptype (left_env, left_t)
        ptype (right_env, right_t)
  | MissingFieldInSignature name ->
      bprintf "This file does not export a variable named %a"
        Variable.p name
  | NoSuchTypeInSignature (p, t) ->
      bprintf "This file exports a variable named %a, but it does \
        not have type %a, the only permissions available for it are: %a"
        pname (env, p)
        ptype (env, t)
        ppermission_list (env, p)
  | DataTypeMismatchInSignature (x, reason) ->
      bprintf "Cannot match the definition of %a against the \
          signature because of: %s"
        Variable.p x
        reason
  | NotExclusiveOwns p ->
      bprintf "%a is not exclusive so it cannot hold anything; \
          the only permissions available for it are %a"
        pname (env, p)
        ppermission_list (env, p)
  | VarianceAnnotationMismatch ->
      bprintf "The variance annotations do not match the inferred ones"
;;

let html_error error =
  let env = fst error in
  (* Get a plain-text version of the error *)
  MzPprint.disable_colors ();
  let text = MzString.bsprintf "%a\n" print_error error in
  (* Generate the HTML explanation. *)
  Debug.explain ~text env;
  (* Find out about the command to run. *)
  let f = (fst (TypeCore.location env)).Lexing.pos_fname in
  let f = MzString.replace "/" "_" f in
  let cmd = Printf.sprintf
    "firefox -new-window \"viewer/viewer.html?json_file=data/%s.json\" &"
    f
  in
  (* Let's do it! *)
  ignore (Sys.command cmd)
;;

let warn_or_error env error =
  (* FIXME switch to a better error system *)
  if !Options.pedantic then
    Log.warn "%a" print_error (env, error)
  else if false then
    raise_error env error
;;

let internal_extracterror = snd;;
