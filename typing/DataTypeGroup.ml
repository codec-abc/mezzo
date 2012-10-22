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

open Types
open Expressions

let bind_group_in (points: point list) subst_func_for_thing thing =
  let total_number_of_data_types = List.length points in
  let thing =
    Hml_List.fold_lefti (fun level thing point ->
      let index = total_number_of_data_types - level - 1 in
      subst_func_for_thing (TyPoint point) index thing
    ) thing points
  in
  thing
;;


let bind_group_in_group (points: point list) (group: data_type_group) =
  bind_group_in points tsubst_data_type_group group
;;


let bind_group_definitions (env: env) (points: point list) (group: data_type_group): env =
  List.fold_left2 (fun env point (_, _, def, _, _) ->
    (* Replace the corresponding definition in [env]. *)
    replace_type env point (fun binder ->
      { binder with definition = Some def }
    )
  ) env points group
;;


let bind_group (env: env) (group: data_type_group) =
  (* Allocate the points in the environment. We don't put a definition yet. *)
  let env, points = List.fold_left (fun (env, acc) (name, location, _, fact, kind) ->
    let name = User name in
    let env, point = bind_type env name location fact kind in
    env, point :: acc
  ) (env, []) group in
  let points = List.rev points in

  (* Construct the reverse-map from constructors to points. *)
  let env = List.fold_left2 (fun env (_, _, def, _, _) point ->
    match def with
    | None, _ ->
        env
    | Some (_, def, _), _ ->
        let type_for_datacon = List.fold_left (fun type_for_datacon (name, _) ->
          DataconMap.add name point type_for_datacon
        ) env.type_for_datacon def in  
        { env with type_for_datacon }
  ) env group points in

  env, points
;;


let bind_group_in_blocks (points: point list) (blocks: block list) =
  bind_group_in points tsubst_blocks blocks
;;


let debug_blocks env blocks =
  Log.debug "#### DEBUGGING BLOCKS ####\n";
  List.iter (function
    | DataTypeGroup group ->
        Log.debug "%a\n"
          KindCheck.KindPrinter.pgroup (env, group);
    | ValueDeclarations decls ->
        Log.debug "%a\n"
          Expressions.ExprPrinter.pdeclarations (env, decls);
    | PermDeclaration it ->
        Log.debug "%a\n"
          Expressions.ExprPrinter.psigitem (env, it)
  ) blocks;
  Log.debug "#### END DEBUGGING BLOCKS ####\n"
;;


let bind_data_type_group
    (env: env)
    (group: data_type_group)
    (blocks: block list): env * block list =
  (* First, allocate points for all the data types. *)
  let env, points = bind_group env group in
  (* Open references to these data types in the branches themselves, since the
   * definitions are all mutually recursive. *)
  let group = bind_group_in_group points group in
  (* Attach the definitions! *)
  let env = bind_group_definitions env points group in
  (* Now we can perform some more advanced analyses. *)
  let env = FactInference.analyze_data_types env points in
  let env = Variance.analyze_data_types env points in
  debug_blocks env blocks;
  (* Open references to these data types in the rest of the program. *)
  let blocks = bind_group_in_blocks points blocks in
  debug_blocks env blocks;
  (* We're done. *)
  env, blocks
;;