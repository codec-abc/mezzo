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

(** This module helps deal with interfaces. *)

open Kind
open Either
module S = SurfaceSyntax
module E = ExpressionsCore
module T = TypeCore

(* ---------------------------------------------------------------------------- *)

(* [build_interface env mname iface] desugars the interface [iface] belonging to
 * module [mname]. It returns an environment along with a desugared interface,
 * both suitable for [import_interface]. *)
let build_interface (env: TypeCore.env) (mname: Module.name) (iface: S.interface): T.env * E.interface =
  let env = TypeCore.enter_module env mname in
  let kenv = TypeCore.kenv env in
  KindCheck.check_interface kenv iface;
  env, TransSurface.translate_interface kenv iface
;;

(* Used by [Driver]. See the .mli! *)
let import_interface (env: T.env) (mname: Module.name) (iface: S.interface): T.env =
  Log.debug "Massive import, %a" Module.p mname;
  let env, iface = build_interface env mname iface in

  let open TypeCore in
  let open ExpressionsCore in
  let rec import_items env = function
    | ValueDeclaration (name, typ) :: items ->
        (* Bind the variable. *)
        let binding = User (mname, name), KValue, location env in
        let env, { Expressions.subst_toplevel; vars; _ } = Expressions.bind_evars env [ binding ] in
        let p = match vars with [ p ] -> p | _ -> assert false in

        (* First, remember that we now have a qualified name pointing to [p]. *)
        let env = Exports.bind_interface_value env mname name p in

        (* Then, [add] takes care of simplifying any function type. *)
        let env = Permissions.add env p typ in
        let items = subst_toplevel items in
        import_items env items

    | DataTypeGroup group :: items ->
        let env, items, vars, dc_exports = Expressions.bind_data_type_group_in_toplevel_items env group items in

        (* Also remember that we now have a qualified name for the types, and
         * that we can qualify the data constructors as well. *)
        let env = Exports.bind_interface_types env mname group vars dc_exports in

        import_items env items

    | ValueDefinitions _ :: _ ->
        assert false

    | [] ->
        env
  in

  import_items env iface
;;

(* TEMPORARY suggestion: instead of manually using [translate_type]
   and [translate_data_type_group], maybe we could translate the
   entire interface at once using [translate_interface] -- suitably extended
   with a [bind] parameter that allows choosing the right points. Then, there
   would only remain to compare implementation & interface, both expressed in
   the core language. *)

(* Check that [env] respect the [signature] which is that of module [mname]. We
 * will want to check that [env] respects its own signature.
 *
 * Why does this function return an environment? To print the final signature, I
 * guess... *)
let check
  (env: T.env)
  (signature: S.toplevel_item list)
: T.env =

  (* All exported variables are unqualified, non-local variables. *)
  let exports = TypeCore.kenv env in

  (* As [check] processes one toplevel declaration after another, it first adds
   * the name into the translation environment (i.e. after processing [val foo @ τ],
   * [foo] is known to point to a point in [env] in [tsenv]). Second, in
   * order to check [val foo @ τ], it removes [τ] from the list of available
   * permissions for [foo] in [env], which depletes as we go. *)
  let rec check (env: T.env) (tsenv: TransSurface.env) (toplevel_items: S.toplevel_item list) =
    match toplevel_items with
    | S.OpenDirective mname :: toplevel_items ->
        let tsenv = KindCheck.dissolve tsenv mname in
        check env tsenv toplevel_items

    | S.ValueDeclaration ((x, _, _loc), t) :: toplevel_items ->
        (* val x: t *)
        Log.debug ~level:3 "*** Checking sig item %a" Variable.p x;

        (* Now translate type [t] into the internal syntax; [x] is not bound in
         * [t]. *)
        let t = TransSurface.translate_type_reset tsenv t in

        (* Signatures now must only contain duplicable exports. *)
        if not (FactInference.is_duplicable env t) then
          TypeErrors.(raise_error env (ExportNotDuplicable x));

        (* Now check that the point in the implementation's environment actually
         * has the same type as the one in the interface. *)
        let point = KindCheck.find_nonlocal_variable exports x in
        let env =
          match Permissions.sub env point t with
          | Left (env, derivation) ->
              Log.debug ~level:6 "\nDerivation for %a: %a\n"
                Variable.p x
                DerivationPrinter.pderivation derivation;
              env
          | Right d ->
              let open TypeErrors in
              raise_error env (NoSuchTypeInSignature (point, t, d))
        in

        (* Alright, [x] is now bound, and when it appears afterwards, it will
         * refer to the original [x] from [env]. *)
        let tsenv = KindCheck.bind_nonlocal tsenv (x, KValue, point) in

        (* Check the remainder of the toplevel_items. *)
        check env tsenv toplevel_items

    | S.DataTypeGroup group :: toplevel_items ->

        (* Translate this data type group, while taking care to re-use
          the existing points in [env]. *)
        let special_bind tsenv (name, kind, _loc) =
          KindCheck.bind_nonlocal tsenv (name, kind, KindCheck.find_nonlocal_variable exports name)
        in
        let tsenv, translated_definitions =
          TransSurface.translate_data_type_group (List.fold_left special_bind) tsenv group
        in

        (* Check that the translated definitions from the interface and the known
         * definitions from the implementations are consistent. *)
        flush stdout;
        flush stderr;
        List.iter (fun data_type ->
          let {
            T.data_name = name;
            data_kind = k;
            data_variance = variance;
            data_definition = def;
            data_fact = fact;
            _
          } = data_type in

          let point = KindCheck.find_nonlocal_variable exports name in
          (* Variables marked with ' belong to the implementation. *)

          let open TypeErrors in
          let error_out reason =
            raise_error env (DataTypeMismatchInSignature (name, reason))
          in

          (* Check kinds. *)
          let k' = T.get_kind env point in
          if k <> k' then
            error_out "kinds";

          (* Check facts. We check that the fact in the implementation is more
           * precise than the fact in the signature. *)
          let fact' = T.get_fact env point in

          (* Definitions. *)
          let def' = Option.extract (T.get_definition env point) in
          let variance' = T.get_variance env point in

          if not (List.for_all2 Variance.leq variance' variance) then
            error_out "variance";

          (* match [the-one-from-the-interface], [the-one-from-the-implem] with *)
          match def, def' with
          | T.Abstract, T.Abstract
              (* When re-matching a module against the interfaces it opened,
               * we'll encounter the case where in [env] the type is defined as
               * abstract, and in the signature it is still abstract.
               *
               * [TransSurface] authorizes declaring a type as abstract
               * in an implementation: we just re-check the fact, since the
               * kinds have been checked earlier already. *)
          | T.Abstract, T.Abbrev _
          | T.Abstract, T.Concrete _ ->
              (* Type made abstract. We just check that the facts are
               * consistent. The fact information in [fact'] (the
               * implementation) is correct, since [Driver] took care of running
               * [DataTypeGroup.bind_data_type_group]. The fact from the
               * interface, i.e. [fact], is correct because the fact for an
               * abstract is purely syntactical and does not depend on having
               * run [FactInference.analyze_types] properly. *)
              if not (Fact.leq fact' fact) then
                error_out "facts";

          | T.Concrete branches, T.Concrete branches' ->
              (* We're not checking facts: if the branches are
               * equal, then it results that the facts are equal. Moreover, we
               * haven't run [FactInference.analyze_types] on the *signature* so
               * the information in [fact] is just meaningless. *)

              List.iter2 (fun t t' ->
                (* Resolve the data constructor from the interface, so that we
                 * can leverage [equal] to do all the comparison work for us. *)
                let t = T.touch_branch t (fun b ->
                  Expressions.resolve_branch point b
                ) in

                if not (T.equal env t t') then begin
                  let msg = MzString.bsprintf
                    "different definitions between %a and %a"
                    Types.TypePrinter.ptype (env, t)
                    Types.TypePrinter.ptype (env, t')
                  in
                  error_out msg;
                end;
              ) branches branches';

          | T.Abbrev t, T.Abbrev t' ->
              (* We must export exactly the same abbreviation for the
               * signature to match. *)
              if not (T.equal env t t') then
                error_out "abbreviations not compatible";

          | _ ->
              error_out "definition mismatch"

        ) translated_definitions.T.group_items;

        (* Check the remainder of the toplevel_items. *)
        check env tsenv toplevel_items


    | S.ValueDefinitions _ :: _ ->
        assert false

    | [] ->
        env
  in

  (* We need to build the interface in a "clean" kind-checking environment where
   * the names from the *implementation* are not available. Currently, [env]
   * contains a kind-checking environment where names from the *implementation*
   * are non-local, unqualified variables. We need to zap these, and this is
   * precisely what [enter_module] does. *)
  let tsenv = TypeCore.kenv (TypeCore.enter_module env (TypeCore.module_name env)) in

  check env tsenv signature
;;
