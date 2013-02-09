open Ocamlbuild_plugin

(* We assume that [mezzo] is in the PATH. *)
(* TEMPORARY how to be more flexible? *)
(* TEMPORARY what is the meaning of ocamlbuild's V? *)

let mezzo =
  A "mezzo"

(* This command invokes the Mezzo compiler. *)

let compile env builder =
  Cmd (S [
    mezzo;
    A "-c";
    P (env "%.mz");
    Sh ">/dev/null"; (* TEMPORARY we have to suppress Mezzo's verbose output *)
  ])

(* The following two rules tell how to compile [Mezzo] files. If we have
   both [.mz] and [.mzi] files, then we produce both [.ml] and [.mli]
   files. If we have just an [.mz] file, then we produce just an [.ml]
   file. *)

(* TEMPORARY not sure that ocamlbuild understands these overlapping rules; test! *)

let () =
  rule
    "mezzo-mz-mzi"              (* the name of the rule, which should be unique *)
    ~deps:["%.mz";"%.mzi"]      (* the source files *)
    ~prods:["mz%.ml";"mz%.mli"] (* the target files *)
    compile

let () =
  rule
    "mezzo-mz"                  (* the name of the rule, which should be unique *)
    ~dep:"%.mz"                 (* the source file *)
    ~prod:"mz%.ml"              (* the target file *)
    compile

(* Options for the OCaml compiler. *)

let () =
  dispatch (function
    | After_rules ->
        (* Disable the warning about statements that never return. *)
        flag ["ocaml"; "compile"] (S[A "-w"; A "-21"]);
        (* Do not load the ocaml core library or the standard library. *)
        flag ["ocaml"; "compile"] (S[A "-nopervasives"; A "-nostdlib"]);
        flag ["ocaml"; "link"] (S[A "-nopervasives"; A "-nostdlib"]);
    | _ ->
        ()
  )
