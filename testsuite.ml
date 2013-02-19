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

module K = KindCheck

open TypeCore
open Types
open TestUtils
open TypeErrors

let check env point t =
  match Permissions.sub env point t with
  | Some _ ->
      ()
  | None ->
      raise_error env (ExpectedType (t, point))
;;

let point_by_name env ?mname name =
  point_by_name env ?mname (Variable.register name)
;;

type outcome =
  (* Fail at kind-checking time. *)
  | KFail of (KindCheck.raw_error -> bool)
  (* Fail at type-checking time. *)
  | Fail of (raw_error -> bool)
  | Pass

exception KnownFailure

let simple_test ?(pedantic=false) ?known_failure outcome = fun do_it ->
  let known_failure = Option.unit_bool known_failure in
  let raise_if (e: exn): unit =
    if not known_failure then
      raise e
    else
      raise KnownFailure
  in
  let success_if (): unit =
    if known_failure then
      raise (Failure "Test started working, remove ~known_failure!")
  in
  try
    Options.pedantic := pedantic;
    ignore (do_it ());
    match outcome with
    | KFail _ ->
        raise_if (Failure "Test passed, it was supposed to fail")
    | Fail _ ->
        raise_if (Failure "Test passed, it was supposed to fail")
    | Pass ->
        success_if ()
  with
  | TypeCheckerError e ->
      let e = internal_extracterror e in
      begin match outcome with
      | Pass ->
          raise_if (Failure "Test failed, it was supposed to pass")
      | Fail f ->
          if f e then
            success_if ()
          else
            raise_if (Failure "Test failed but not for the right reason")
      | KFail _ ->
          raise_if (Failure "Test failed but not for the right reason")
      end

  | K.KindError (_, e) ->
      begin match outcome with
      | Pass ->
          raise_if (Failure "Test failed, it was supposed to pass")
      | KFail f ->
          if f e then
            success_if ()
          else
            raise_if (Failure "Test failed but not for the right reason")
      | Fail _ ->
          raise_if (Failure "Test failed but not for the right reason")
      end
;;

let dummy_loc =
  Lexing.dummy_pos, Lexing.dummy_pos
;;

let dummy_name =
  User (Module.register "<none>", Variable.register "foo")
;;

let edummy_binding k =
  dummy_name, k, dummy_loc
;;

let dummy_binding k =
  (dummy_name, k, dummy_loc), CanInstantiate
;;

let tests: (string * ((unit -> env) -> unit)) list = [
  ("absdefs.mz",
    simple_test Pass);

  (* Some very simple tests. *)

  ("basic.mz",
    simple_test Pass);

  ("constructors.mz",
    simple_test Pass);

  ("dcscope2.mz",
    simple_test (KFail (function K.UnboundDataConstructor _ -> true | _ -> false)));

  ("modules/dcscope.mz",
    simple_test (KFail (function K.UnboundDataConstructor _ -> true | _ -> false)));

  ("constructors_bad_1.mz",
    simple_test (Fail (function MissingField _ -> true | _ -> false)));

  ("constructors_bad_2.mz",
    simple_test (Fail (function ExtraField _ -> true | _ -> false)));

  ("field_access.mz",
    simple_test Pass);

  ("field_access_bad.mz",
    simple_test (Fail (function NoSuchField _ -> true | _ -> false)));

  ("field_assignment.mz",
    simple_test Pass);

  ("field_assignment_bad.mz",
    simple_test (Fail (function NoSuchField _ -> true | _ -> false)));

  ("arithmetic.mz", fun do_it ->
    let env = do_it () in
    let int = find_type_by_name env ~mname:"int" "int" in
    let foo = point_by_name env "foo" in
    let bar = point_by_name env "bar" in
    check env foo int;
    check env bar int);

  ("wrong_type_annotation.mz",
    simple_test (Fail (function ExpectedType _ -> true | _ -> false)));

  ("constraints_in_patterns.mz",
    simple_test (Fail (function ExpectedType _ -> true | _ -> false)));

  ("constraints_in_patterns2.mz",
    simple_test Pass);

  ("constraints_in_patterns3.mz",
    simple_test Pass);

  ("constraints_in_patterns4.mz",
    simple_test Pass);

  ("function.mz", fun do_it ->
    let env = do_it () in
    let int = find_type_by_name env ~mname:"int" "int" in
    let foobar = point_by_name env "foobar" in
    check env foobar (tuple [int; int]));

  ("stupid_match.mz",
    simple_test (Fail (function MatchBadDatacon _ -> true | _ -> false)));

  ("value_restriction.mz",
    simple_test (Fail (function NoSuchField _ -> true | _ -> false)));
  ("value_restriction2.mz",
    simple_test Pass);
  ("value_restriction3.mz",
    simple_test Pass);
  ("value_restriction4.mz",
    simple_test (Fail (function _ -> true)));

  ("variance.mz", fun do_it ->
    let env = do_it () in
    let check_variance n vs =
      let t = find_type_by_name env n in
      match get_definition env !!t with
      | Some (_, vs') when vs = vs' ->
          ()
      | _ ->
          failwith "Variances don't match"
    in
    let co = Covariant and contra = Contravariant and bi = Bivariant and inv = Invariant in
    check_variance "list" [co];
    check_variance "ref" [co]; (* yes *)
    check_variance "bi" [bi];
    check_variance "inv" [inv];
    check_variance "test" [co; co; bi];
    check_variance "contra" [contra];
    check_variance "adopts_contra" [contra];
  );

  ("stupid-swap.mz",
    simple_test Pass
  );

  ("multiple_fields_and_permissions.mz",
    simple_test Pass
  );

  ("anonargs.mz", simple_test Pass);

  ("pattern1.mz", simple_test Pass);

  ("pattern2.mz", simple_test Pass);

  ("pattern3.mz", simple_test Pass);

  ("pattern4.mz", simple_test Pass);

  ("loose_variable.mz", simple_test Pass);

  ("double-open.mz", simple_test Pass);

  ("double-open2.mz", simple_test Pass);

  ("multiple_data_type_groups.mz", simple_test Pass);

  ("hole.mz", simple_test Pass);

  ("curry1.mz", simple_test Pass);

  ("impredicative.mz", simple_test Pass);

  ("impredicative2.mz", simple_test Pass);

  ("impredicative3.mz", simple_test (Fail (function
    | ExpectedType _ -> true
    | _ -> false
  )));

  ("impredicative4.mz", simple_test (Fail (function
    | ExpectedType _ -> true
    | _ -> false
  )));

  ("impredicative5.mz", simple_test Pass);

  ("twostructural.mz", simple_test Pass);

  (* The merge operation and all its variations. *)

  ("merge1.mz", fun do_it ->
    let env = do_it () in
    let v1 = point_by_name env "v1" in
    check env v1 (TyConcreteUnfolded (dc env "t" "T", [], ty_bottom)));

  ("merge2.mz", fun do_it ->
    let env = do_it () in
    let v2 = point_by_name env "v2" in
    let t = TyExists (edummy_binding KTerm,
      TyBar (
        ty_equals v2,
        TyStar (
          TyAnchoredPermission (TyOpen v2,
            TyConcreteUnfolded (dc env "u" "U",
              [FieldValue (Field.register "left", TySingleton (TyBound 0));
               FieldValue (Field.register "right", TySingleton (TyBound 0))], ty_bottom)),
          TyAnchoredPermission (
            TyBound 0,
            TyConcreteUnfolded (dc env "t" "T", [], ty_bottom)
          )
        )
      ))
    in
    check env v2 t);

  ("merge3.mz", fun do_it ->
    let env = do_it () in
    let v3 = point_by_name env "v3" in
    let t = TyExists (edummy_binding KTerm,
      TyExists (edummy_binding KTerm,
        TyBar (
          ty_equals v3,
          fold_star [
            TyAnchoredPermission (TyOpen v3,
              TyConcreteUnfolded (dc env "u" "U",
                [FieldValue (Field.register "left", TySingleton (TyBound 0));
                 FieldValue (Field.register "right", TySingleton (TyBound 1))],
                 ty_bottom));
            TyAnchoredPermission (
              TyBound 0,
              TyConcreteUnfolded (dc env "t" "T", [], ty_bottom)
            );
            TyAnchoredPermission (
              TyBound 1,
              TyConcreteUnfolded (dc env "t" "T", [], ty_bottom)
            );
          ]
        )))
    in
    check env v3 t);

  ("merge4.mz", fun do_it ->
    let env = do_it () in
    let v4 = point_by_name env "v4" in
    let w = find_type_by_name env "w" in
    let int = find_type_by_name env ~mname:"int" "int" in
    let t = TyApp (w, [int]) in
    check env v4 t);

  ("merge5.mz", fun do_it ->
    let env = do_it () in
    let v5 = point_by_name env "v5" in
    let v = find_type_by_name env "v" in
    let int = find_type_by_name env ~mname:"int" "int" in
    let t = TyApp (v, [int; int]) in
    check env v5 t);

  ("merge6.mz", simple_test Pass);

  ("merge7.mz", simple_test Pass);

  ("merge8.mz", fun do_it ->
    let env = do_it () in
    let v8 = point_by_name env "v8" in
    let v = find_type_by_name env "v" in
    let t = TyForall (dummy_binding KType,
        TyApp (v, [TyBound 0; TyBound 0])
      )
    in
    check env v8 t);

  ("merge9.mz", fun do_it ->
    let env = do_it () in
    let v9 = point_by_name env "v9" in
    let ref = find_type_by_name env "ref" in
    let int = find_type_by_name env ~mname:"int" "int" in
    let t = TyApp (ref, [int]) in
    check env v9 t);

  ("merge10.mz", fun do_it ->
    let env = do_it () in
    let v10 = point_by_name env "v10" in
    let foo = find_type_by_name env "foo" in
    let t = find_type_by_name env "t" in
    let t = TyApp (foo, [t]) in
    check env v10 t);

  ("merge11.mz", fun do_it ->
    let env = do_it () in
    let v11 = point_by_name env "v11" in
    let ref = find_type_by_name env "ref" in
    let int = find_type_by_name env ~mname:"int" "int" in
    let t = TyApp (ref, [TyApp (ref, [int])]) in
    check env v11 t);

  ("merge12.mz", fun do_it ->
    let env = do_it () in
    let v12 = point_by_name env "v12" in
    let int = find_type_by_name env ~mname:"int" "int" in
    (* Urgh, have to input internal syntax to check function types... maybe we
     * should write surface syntax here and have it simplified by the desugar
     * procedure? ... *)
    let t = TyForall (dummy_binding KTerm, TyArrow (
      TyBar (
        TySingleton (TyBound 0),
        TyAnchoredPermission (TyBound 0, int)
      ), int))
    in
    check env v12 t);

  ("merge13.mz", fun do_it ->
    let env = do_it () in
    let v13 = point_by_name env "v13" in
    let x = point_by_name env "x" in
    let int = find_type_by_name env ~mname:"int" "int" in
    let t = find_type_by_name env "t" in
    let t = TyApp (t, [int]) in
    check env v13 t;
    check env x int);

  ("merge14.mz", fun do_it ->
    let env = do_it () in
    let v14 = point_by_name env "v14" in
    let int = find_type_by_name env ~mname:"int" "int" in
    let t = find_type_by_name env "t" in
    (* Look at how fancy we used to be when we had singleton-subtyping! *)
    (* let t = TyExists (edummy_binding KTerm, TyBar (
      TyApp (t, [TySingleton (TyBound 0)]),
      TyAnchoredPermission (TyBound 0, int)
    )) in *)
    let t = TyApp (t, [int]) in
    check env v14 t);

  ("merge15.mz", simple_test Pass);

  ("merge16.mz", simple_test Pass);

  ("merge18.mz", simple_test Pass);

  ("merge19.mz", simple_test Pass);

  ("merge_generalize_val.mz", simple_test Pass);

  ("constraints_merge.mz",
    simple_test ~pedantic:true Pass);

  (* Resource allocation conflicts. *)

  ("conflict2.mz",
    simple_test ~pedantic:true Pass);

  (* Singleton types. *)

  ("singleton1.mz", fun do_it ->
    Options.pedantic := false;
    let env = do_it () in
    let x = point_by_name env "x" in
    let s1 = point_by_name env "s1" in
    let t = find_type_by_name env "t" in
    (* We have to perform a syntactic comparison here, otherwise [check] which
     * uses [sub] under the hood might implicitly perform the
     * singleton-subtyping-rule -- this would defeat the whole purpose of the
     * test. *)
    let perms = get_permissions env x in
    if List.exists (FactInference.is_exclusive env) perms then
      failwith "The permission on [x] should've been consumed";
    let perms = get_permissions env s1 in
    if not (List.exists ((=) (TyApp (t, [datacon env "t" "A" []]))) perms) then
      failwith "The right permission was not extracted for [s1].";
  );

  (* Doesn't pass anymore since we removed singleton-subtyping! *)
  (* ("singleton2.mz", simple_test Pass); *)

  (* Marking environments as inconsistent. *)

  ("inconsistent1.mz",
    simple_test Pass
  );

  ("inconsistent2.mz",
    simple_test Pass
  );

  (* Duplicity constraints. *)

  ("duplicity1.mz",
    simple_test Pass
  );

  ("duplicity2.mz",
    simple_test Pass
  );

  (* Polymorphic function calls *)

  ("polycall1.mz",
    simple_test (Fail (function IllKindedTypeApplication _ -> true | _ -> false)));

  ("polycall2.mz",
    simple_test (Fail (function BadTypeApplication _ -> true | _ -> false)));

  ("polycall3.mz",
    simple_test ~pedantic:true Pass);

  ("polycall4.mz",
    simple_test ~pedantic:true Pass);

  ("polycall5.mz",
    simple_test ~pedantic:true Pass);

  ("polycall6.mz",
    simple_test ~pedantic:true Pass);

  (* Tests are expected to fail. *)

  ("fail1.mz",
    simple_test ((Fail (function ExpectedType _ -> true | _ -> false))));

  ("fail2.mz",
    simple_test ((Fail (function ExpectedType _ -> true | _ -> false))));

  ("fail3.mz",
    simple_test ((Fail (function NoSuchField _ -> true | _ -> false))));

  ("fail4.mz",
    simple_test ((Fail (function NoSuchPermission _ -> true | _ -> false))));

  ("fail5.mz",
    simple_test ((Fail (function NoSuchPermission _ -> true | _ -> false))));

  ("fail6.mz",
    simple_test ((Fail (function ExpectedType _ -> true | _ -> false))));

  ("fail7.mz",
    simple_test ((Fail (function FieldMismatch _ -> true | _ -> false))));

  ("fail8.mz",
    simple_test ((Fail (function BadPattern _ -> true | _ -> false))));

  ("fail9.mz",
    simple_test ((Fail (function NotDynamic _ -> true | _ -> false))));

  ("fail10.mz",
    simple_test ((Fail (function BadField _ -> true | _ -> false))));

  (* Adoption. *)

  ("adopts1.mz",
    simple_test Pass);

  ("adopts2.mz",
    simple_test (Fail (function BadFactForAdoptedType _ -> true | _ -> false)));

  ("adopts3.mz",
    simple_test (KFail (function K.AdopterNotExclusive _ -> true | _ -> false)));

  ("adopts4.mz",
    simple_test (Fail (function BadFactForAdoptedType _ -> true | _ -> false)));

  ("adopts5.mz",
    simple_test Pass);

  ("adopts6.mz",
    simple_test Pass);

  ("adopts7.mz",
    simple_test Pass);

  ("adopts8.mz",
    simple_test (Fail (function BadFactForAdoptedType _ -> true | _ -> false)));

  ("adopts9.mz",
    simple_test Pass);

  ("adopts10.mz",
    simple_test (Fail (function NotMergingClauses _ -> true | _ -> false)));

  ("adopts12.mz",
    simple_test Pass);

  (* Bigger examples. *)

  ("list-length.mz", fun do_it ->
    let env = do_it () in
    let int = find_type_by_name env ~mname:"int" "int" in
    let zero = point_by_name env "zero" in
    check env zero int);

  ("list-length-variant.mz", simple_test Pass);

  ("list-concat.mz", simple_test Pass);

  ("list-concat-dup.mz",
    simple_test Pass
  );

  ("list-length.mz",
    simple_test Pass
  );

  ("list-map0.mz",
    simple_test Pass
  );

  ("list-map1.mz",
    simple_test Pass
  );

  ("list-map2.mz",
    simple_test Pass
  );

  ("list-map3.mz",
    simple_test Pass
  );

  ("list-map-tail-rec.mz",
    simple_test Pass
  );

  ("list-rev.mz",
    simple_test Pass
  );

  ("list-find.mz",
    simple_test Pass
  );

  ("list-mem2.mz",
    simple_test Pass
  );

  ("list-id.mz",
    simple_test Pass
  );

  ("xlist-copy.mz",
    simple_test Pass
  );

  ("xlist-concat.mz",
    simple_test Pass
  );

  ("xlist-concat1.mz",
    simple_test Pass
  );

  ("xlist-concat2.mz",
    simple_test Pass
  );

  ("tree_size.mz",
    simple_test Pass
  );

  ("in_place_traversal.mz",
    simple_test Pass
  );

  ("counter.mz",
    simple_test Pass
  );

  ("xswap.mz",
    simple_test Pass
  );

  ("bag_lifo.mz", simple_test Pass);

  ("bag_fifo.mz", simple_test Pass);

  (* ("landin.mz", simple_test Pass); *)

  ("modules/simple.mz", simple_test Pass);

  ("modules/simple2.mz", simple_test (Fail (function
    | DataTypeMismatchInSignature _ -> true | _ -> false
  )));

  ("modules/m.mz", simple_test Pass);

  ("modules/exporttwo.mz", simple_test Pass);

  ("modules/qualified.mz", simple_test Pass);

  ("modules/equations_in_mzi.mz", simple_test Pass);

  ("assert.mz", simple_test Pass);

  ("priority.mz", simple_test Pass);

  ("fieldEvaluationOrder.mz", simple_test Pass);

  ("fieldEvaluationOrderReject1.mz", simple_test (Fail (function _ -> true)));

  ("fieldEvaluationOrderReject2.mz", simple_test (Fail (function _ -> true)));

  ("monads.mz", simple_test Pass);

  ("adopts-non-mutable-type.mz", simple_test (Fail (function BadFactForAdoptedType _ -> true | _ -> false)));

  ("adopts-type-variable.mz", simple_test (Fail (function BadFactForAdoptedType _  -> true | _ -> false)));

  ("ref-confusion.mz", simple_test (KFail (function _ -> true)));

  ("strip_floating_perms.mz", simple_test (Fail (function ExpectedType _ -> true | _ -> false)));

  ("fact-inconsistency.mz", simple_test Pass);

  ("dfs.mz", simple_test Pass);

  ("dfs-owns.mz", simple_test Pass);

  ("owns1.mz", simple_test Pass);

  ("owns2.mz", simple_test (Fail (function NotDynamic _ -> true | _ -> false)));

  ("owns3.mz", simple_test Pass);

  ("tuple-syntax.mz", simple_test Pass);

  ("same-type-var-bug.mz", simple_test (KFail (function K.BoundTwice _ -> true | _ -> false)));

  ("assert-bug.mz", simple_test ~known_failure:() Pass);

  ("function-comparison.mz", simple_test Pass);

  ("function-comparison2.mz", simple_test (Fail (function _ -> true)));

  ("masking.mz", simple_test (Fail (fun _ -> true)));

  ("masking2.mz", simple_test (Fail (function _ -> true)));

  ("masking3.mz", simple_test Pass);

  ("bad-linearity.mz", simple_test (Fail (function _ -> true)));

  ("bad-generalization.mz", simple_test (Fail (function _ -> true)));

  ("bad-levels.mz", simple_test (Fail (function _ -> true)));

  ("dup-value.mzi", simple_test (KFail (function _ -> true)));

  ("dup-datacon.mzi", simple_test (KFail (function _ -> true)));

  ("unqualified-datacon.mz", simple_test (KFail (function K.UnboundDataConstructor _ -> true | _ -> false)));

  ("improve-inference.mz", simple_test Pass);
  ("improve-inference2.mz", simple_test Pass);

  ("cps-dereliction.mz", simple_test Pass);

  ("fold-permission.mz", simple_test Pass);

  ("abstract.mz", simple_test Pass);

  ("abstract2.mz", simple_test (Fail (function
    | DataTypeMismatchInSignature _ -> true | _ -> false
  )));

  ("ref-swap.mz", simple_test Pass);

  ("multiple-match-ref.mz", simple_test (Fail (fun _ -> true)));

  ("018.mz", simple_test Pass);

  ("vicious-cycle.mz", simple_test Pass);

  ("named-tuple-components.mz", simple_test Pass);

  ("abstract-perm.mz", simple_test Pass);

  ("dup_sign.mz", simple_test (Fail (function NoSuchTypeInSignature _ -> true | _ -> false)));
  ("dup_sign1.mz", simple_test Pass);
  ("dup_sign2.mz", simple_test (Fail (function UnsatisfiableConstraint _ -> true | _ -> false)));
  ("dup_sign3.mz", simple_test Pass);
  ("dup_sign4.mz", simple_test Pass);

  ("tableau.mz", simple_test Pass);
  ("smemoize.mz", simple_test Pass);
  ("use-magic.mz", simple_test Pass);
  ("list2array.mz", simple_test Pass);
  ("sub_constraints_nonpoint_type.mz", simple_test Pass);
  ("merge-tyapp-with-two-subs.mz", simple_test Pass);

  ("exist00.mz", simple_test Pass);
  ("exist01.mz", simple_test Pass);
  ("exist03.mz", simple_test Pass);
  ("exist04.mz", simple_test Pass);
  ("exist05.mz", simple_test Pass);
  ("exist06.mz", simple_test Pass);
  ("exist07.mz", simple_test Pass);
  ("exist08.mz", simple_test ~known_failure:() Pass);
  ("exist09.mz", simple_test Pass);

];;

let mz_files_in_directory (dir : string) : string list =
  let filenames = Array.to_list (Sys.readdir dir) in
  List.filter (fun filename ->
    Filename.check_suffix filename ".mz"
  ) filenames

let corelib_tests: (string * ((unit -> env) -> unit)) list =
  List.map (fun filename -> filename, simple_test Pass) (mz_files_in_directory (Configure.root_dir ^ "/corelib"))
;;

let stdlib_tests: (string * ((unit -> env) -> unit)) list =
  List.map (fun filename -> filename, simple_test Pass) (mz_files_in_directory (Configure.root_dir ^ "/stdlib"))
;;

let _ =
  let open Bash in
  Log.enable_debug (-1);
  Driver.add_include_dir (Filename.concat Configure.root_dir "corelib");
  Driver.add_include_dir (Filename.concat Configure.root_dir "stdlib");
  let failed = ref 0 in
  let names_failed = ref [] in
  let run prefix tests =
    List.iter (fun (file, test) ->
      Log.warn_count := 0;
      let do_it = fun () ->
        let env = Driver.process (Filename.concat prefix file) in
        env
      in
      begin try
        test do_it;
        if !Log.warn_count > 0 then
          Printf.printf "%s✓ %s%s, %s%d%s warning%s\n"
            colors.green colors.default file
            colors.red !Log.warn_count colors.default
            (if !Log.warn_count > 1 then "s" else "")
        else
          Printf.printf "%s✓ %s%s\n" colors.green colors.default file;
      with
      | KnownFailure ->
          Printf.printf "%s! %s%s\n" colors.orange colors.default file;
      | Exit ->
          exit 255
      | _ as e ->
          failed := !failed + 1;
          names_failed := file :: !names_failed;
          Printf.printf "%s✗ %s%s\n" colors.red colors.default file;
          print_endline (Printexc.to_string e);
          Printexc.print_backtrace stdout;
      end;
      flush stdout;
      flush stderr;
    ) tests;
  in

  let center s =
    let l = String.length s in
    let padding = String.make ((Bash.twidth - l) / 2) ' ' in
    Printf.printf "%s%s\n" padding s;
  in

  (* Check the core modules. *)
  center "~[ Core Modules ]~";
  run "corelib/" corelib_tests;
  Printf.printf "\n";

  (* Check the standard library modules. *)
  center "~[ Standard Library Modules ]~";
  run "stdlib/" stdlib_tests;
  Printf.printf "\n";

  (* Thrash the include path, and then do the unit tests. *)
  Options.no_auto_include := true;
  Driver.add_include_dir "tests";
  Driver.add_include_dir "tests/modules";
  center "~[ Unit Tests ]~";
  run "tests/" tests;
  Printf.printf "\n";

  Printf.printf "%s%d%s tests run, " colors.blue (List.length tests) colors.default;
  if !failed > 0 then
    let names_failed =
      match !names_failed with
      | [] ->
          assert false
      | hd :: [] ->
          hd
      | hd :: tl ->
          String.concat ", " (List.rev tl) ^ " and " ^ hd
    in
    Printf.printf "%s%d unexpected failure%s (namely: %s), this is BAD!%s\n"
      colors.red
      !failed (if !failed > 1 then "s" else "")
      names_failed
      colors.default
  else
    Printf.printf "%sall passed%s, congratulations.\n" colors.green colors.default;
;;
