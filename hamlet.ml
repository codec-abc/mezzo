(*****************************************************************************)
(*  HaMLet, a ML dialect with a type-and-capability system                   *)
(*  Copyright (C) 2010 Jonathan Protzenko                                    *)
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

let _ =
  let arg_filename = ref "" in
  let arg_debug = ref 0 in
  let arg_pervasives = ref true in
  let usage = "HaMLet: a next-generation version of ML\n\
    Usage: " ^ Sys.argv.(0) ^ " [OPTIONS] FILE\n"
  in
  Arg.parse
    [
    "-nopervasives", Arg.Clear arg_pervasives, "don't try to prepend pervasives.hml to the file";
    "-debug", Arg.Set_int arg_debug, "output level: 0 (default) = no messages, 4 = super verbose";
    "-I", Arg.String Driver.add_include_dir, "include this directory";
    ]
    (fun f ->
      if !arg_filename = "" then
        arg_filename := f
      else
        failwith "Only one filename should be specified.\n"
    )
    usage;
  Log.enable_debug !arg_debug;
  let env = Driver.run (fun () -> Driver.process !arg_pervasives !arg_filename) in
  (* let env = Driver.process !arg_filename in *)
  Log.debug ~level:1 "%a"
    Types.TypePrinter.pdoc (Types.TypePrinter.print_permissions, env);
;;
