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

(* ---------------------------------------------------------------------------- *)

(* Syntactic categories of names. *)

(* Term variables, type variables, type constructors, and fields are not
   syntactically distinguished. Placing term variables, type variables, and
   type constructors within a single syntactic category is natural because
   they share certain mechanisms (e.g. types and terms can be abstracted over
   them). They will be distinguished using sorts. Placing term variables and
   fields within a single syntactic category is required because we wish to
   allow puns. *)

%token<string> LIDENT

(* As in ocaml, we set up a separate namespace for data constructors. This allows
   distinguishing variables and data constructors in a pattern. (Another solution
   would be to require data constructors to be explicitly followed with braces.) *)

%token<string> UIDENT

(* ---------------------------------------------------------------------------- *)

(* Other tokens. *)

%token          OPEN
%token          KTERM KTYPE KPERM
%token          UNKNOWN DYNAMIC EXCLUSIVE MUTABLE
%token          DATA BAR
%token          LBRACKET RBRACKET LBRACE RBRACE LPAREN RPAREN
%token          COMMA COLON COLONCOLON SEMI STAR AT AS
%token          ARROW LARROW DBLARROW TAGOF FUN
%token          EQUAL
%token          EMPTY ASSERT EXPLAIN FAIL
%token          CONSUMES DUPLICABLE FACT ABSTRACT
%token          VAL LET REC AND IN DOT WITH BEGIN END MATCH
%token          IF THEN ELSE
%token          TAKE FROM GIVE TO ADOPTS
%token<int>     INT
%token          MINUS
%token<string>  OPPREFIX OPINFIX0 OPINFIX1 OPINFIX2 OPINFIX3
%token          EOF

%nonassoc THEN
%nonassoc ELSE

%left     OPINFIX0 MINUS (* MINUS is also an OPINFIX0 *)
%left     EQUAL (* EQUAL is also a OPINFIX0 *)
%right    OPINFIX1
%left     OPINFIX2
%left     OPINFIX3
%left     STAR (* STAR is also an OPINFIX3 *)

(* ---------------------------------------------------------------------------- *)

(* Miscellaneous directives. *)

%start <SurfaceSyntax.implementation> implementation
%start <SurfaceSyntax.interface> interface
%type <SurfaceSyntax.expression> expression
%type <SurfaceSyntax.declaration> declaration

%{

open SurfaceSyntax
open ParserUtils

%}

%%

(* ---------------------------------------------------------------------------- *)

(* Namespaces. *)

(* We work with several namespaces, each of which is obtained by applying
   the functor [Identifier.Make] and defines an abstract type [name]. This
   should help us avoid confusions between namespaces: names for variables,
   data constructors, etc. have distinct types. *)

%inline operator:
  | o = OPPREFIX
  | o = OPINFIX0
  | o = OPINFIX1
  | o = OPINFIX2
  | o = OPINFIX3
    { o }
  | STAR
    { "*" }
  | MINUS
    { "-" }
  | EQUAL
    { "=" }

variable:
  | x = LIDENT
  | LPAREN x = operator RPAREN
    { Variable.register x }

%inline datacon:
  datacon = UIDENT
    { Datacon.register datacon }

%inline module_name:
  name = UIDENT
    { Module.register name }

(* ---------------------------------------------------------------------------- *)

(* Flexible lists. *)

separated_or_terminated_list(sep, X):
| (* nothing *)
    { [] }
| xs = terminated(X, sep)+
| xs = separated_nonempty_list(sep, X)
    { xs }

separated_or_preceded_list(sep, X):
| (* nothing *)
    { [] }
| xs = preceded(sep, X)+
| xs = separated_nonempty_list(sep, X)
    { xs }

%inline separated_list_of_at_least_two(sep, X):
| x1 = X sep x2 = separated_list(sep, X)
    { x1 :: x2 }

(* ---------------------------------------------------------------------------- *)

(* Syntax for type/type applications. *)

(* Applications of types to types are based on juxtaposition, just like
   applications of terms to terms. *)

(* Within the syntax of types, type/type applications are considered
   binary, but in certain places, as in the left-hand side of a data
   type definition, we must allow iterated applications. *)

%inline type_type_application(X, Y):
  ty1 = X ty2 = Y (* juxtaposition *)
    { TyApp (ty1, ty2) }

%inline iterated_type_type_application(X, Y):
  x = X ys = Y* (* iterated juxtaposition *)
    { x, ys }

(* ---------------------------------------------------------------------------- *)

(* Syntax for type abstraction and universal quantification. *)

type_parameters:
| LBRACKET bs = separated_or_terminated_list(COMMA, type_binding) RBRACKET
    { bs }

(* ---------------------------------------------------------------------------- *)

(* Syntax for binding type variables. *)

(* Because the syntax of type/type applications is juxtaposition, the
   syntax of type variable bindings must be atomic (well-delimited). *)

atomic_type_binding:
| x = variable (* KTYPE is the default kind *)
    { x, KType, ($startpos, $endpos) }
| LPAREN b = type_binding RPAREN
    { b }

type_binding:
| b = atomic_type_binding
    { b }
| x = variable COLONCOLON kind = kind
    { x, kind, ($startpos, $endpos) }

(* ---------------------------------------------------------------------------- *)

(* Kinds. *)

atomic_kind:
| LPAREN kind = kind RPAREN
    { kind }
| KTERM
    { KTerm }
| KTYPE
    { KType }
| KPERM
    { KPerm }

%inline kind:
| kind = atomic_kind
    { kind }

(* ---------------------------------------------------------------------------- *)

(* Types and permissions. *)

(* Because types and permissions are distinguished via the kind system, they
   are not (and must not be) distinguished in the syntax. Thus, the
   productions that concern permissions (the empty permission, anchored
   permissions, permission conjunction, etc.) appear as part of the syntax of
   types. *)

(* The syntax of types is stratified into the following levels:

     atomic_type
     tight_type
     normal_type
     loose_type
     consumes_type
     very_loose_type
     fat_type

*)

%inline tlocated (X):
| x = X
    { TyLocated (x, $startpos, $endpos) }

%inline atomic_type:
| t = tlocated(raw_atomic_type)
    { t }

raw_atomic_type:
(* The empty tuple type. *)
| LPAREN RPAREN
    { TyTuple [] }
(* Parentheses are used as a disambiguation device, as is standard. *)
| LPAREN t = arbitrary_type RPAREN
    { t }
(* The top type. *)
| UNKNOWN
    { TyUnknown }
(* The type [dynamic] represents a permission to test membership in a dynamic region. *)
| DYNAMIC
    { TyDynamic }
(* The top permission. A neutral element for permission conjunction. *)
| EMPTY
    { TyEmpty }
(* Term variable, type variable, permission variable, abstract type, or concrete type. *)
| x = variable
    { TyVar x }
(* A variable just like above, prefixed with a module name. *)
| m = module_name COLONCOLON x = variable
    { TyQualified (m, x) }
(* A structural type explicitly mentions a data constructor. *)
(* TEMPORARY add support for optional adopts clause in structural permissions *)
| b = data_type_def_branch
    { TyConcreteUnfolded b }

%inline tight_type:
| t = tlocated(raw_tight_type)
    { t }

raw_tight_type:
| ty = raw_atomic_type
    { ty }
(* A singleton type. *)
| EQUAL x = variable
    { TySingleton (TyVar x) }
(* A type application. *)
| ty = type_type_application(tight_type, atomic_type)
    { ty }

%inline normal_type:
| t = tlocated(raw_normal_type)
    { t }

raw_normal_type:
| ty = raw_tight_type
    { ty }
(* The syntax of function types is [t -> t], as usual. *)
| ty1 = tight_type ARROW ty2 = normal_type
    { TyArrow (ty1, ty2) }
(* A polymorphic type. *)
| bs = type_parameters ty = normal_type
    { List.fold_right (fun b ty -> TyForall (b, ty)) bs ty }

%inline loose_type:
| t = tlocated(raw_loose_type)
    { t }

(* TEMPORARY raw_anchored_permission can be folded back into
   raw_loose_type if we change the syntax of perm_declaration to use COLON *)
raw_anchored_permission:
(* In an anchored permission [x@t], the name [x] is free. This
   represents an assertion that we have permission to use [x] at
   type [t]. *)
| x = variable AT ty = normal_type
    { TyAnchoredPermission (TyVar x, ty) }
(* [x = y] is also an anchored permission; it is sugar for [x@=y]. *)
| x = variable EQUAL y = variable
    { TyAnchoredPermission (TyVar x, TySingleton (TyVar y)) }

raw_loose_type:
| ty = raw_normal_type
    { ty }
| ty = raw_anchored_permission
    { ty }
(* In a name introduction form [x:t], the name [x] is bound. The scope
   of [x] is defined by somewhat subtle rules that need not concern us
   here. These rules are spelled out later on when we desugar the surface-level
   types into a lower-level representation. *)
| x = variable COLON ty = normal_type
    { TyNameIntro (x, ty) }

%inline consumes_type:
| t = tlocated(raw_consumes_type)
    { t }

raw_consumes_type:
| ty = raw_loose_type
    { ty }
(* A type can be annotated with the [CONSUMES] keyword. This really
   makes sense only in certain contexts, e.g. in the left-hand side of an
   arrow, and possibly further down under tuples, stars, etc. The grammar
   allows this everywhere. This notation is checked for consistency and
   desugared in a separate pass. *)
| CONSUMES ty = loose_type
    { TyConsumes ty }

%inline very_loose_type:
| t = tlocated(raw_very_loose_type)
    { t }

raw_very_loose_type:
| ty = raw_consumes_type
    { ty }
(* Permission conjunction is a binary operator. *)
| ty1 = consumes_type STAR ty2 = very_loose_type
    { TyStar (ty1, ty2) }
(* A tuple type of length at least two is written [t1, ..., tn], without
   parentheses. A tuple type of length one cannot be written -- there is
   no syntax for it. *)
| tcs = separated_list_of_at_least_two(COMMA, consumes_type)
    { TyTuple tcs }

%inline fat_type:
| t = tlocated(raw_fat_type)
  { t }

raw_fat_type:
| ty = raw_very_loose_type
    { ty }
(* The conjunction of a type and a permission is written [t | p]. It is
   typically used as the domain or codomain of a function type. *)
| ty1 = fat_type BAR ty2 = very_loose_type
    { TyBar (ty1, ty2) }
| BAR ty2 = very_loose_type
    { TyBar (TyTuple [], ty2) }

%inline arbitrary_type:
  t = fat_type
    { t }

(* ---------------------------------------------------------------------------- *)

(* Mode constraints are used as part of toplevel function definitions. *)

mode:
| EXCLUSIVE
    { Exclusive }
| DUPLICABLE
    { Duplicable }

%inline atomic_mode_constraint:
| m = mode t = atomic_type
    { m, t }

%inline mode_constraint:
| cs = separated_nonempty_list (COMMA, atomic_mode_constraint) DBLARROW
    { cs }

(* ---------------------------------------------------------------------------- *)

(* Some generic definitions concerning applications of data constructors. *)

(* A data constructor application takes the generic form [D { ... }]. As a
   special case, a pair of empty braces can be omitted. *)

generic_datacon_application(Y):
| dc = datacon (* a pair of empty braces can be omitted *)
    { dc, [] }
| dc = datacon LBRACE ys = Y RBRACE
    { dc, ys }

(* It is often the case that the contents of the curly braces is a semicolon-
   separated (or -terminated) list of things. *)

%inline datacon_application(Y):
| xys = generic_datacon_application(separated_or_terminated_list(SEMI, Y))
    { xys }

(* ---------------------------------------------------------------------------- *)

(* Data type definitions. *)

data_field_def:
(* A field definition normally mentions a field name and a field type. Multiple
   field names, separated with commas, can be specified: this means that they
   share a common type. *)
| fs = separated_nonempty_list(COMMA, variable) COLON ty = normal_type
    { List.map (fun f -> FieldValue (f, ty)) fs }
(* We also allow a field definition to take the form of an equality between
   a field name [f] and a term variable [y]. This is understood as sugar for
   a definition of the field [f] at the singleton type [=y]. In this case,
   only one field name is allowed. This short-hand is useful in the syntax
   of structural permissions. *)
| f = variable EQUAL y = variable
    { [ FieldValue (f, TySingleton (TyVar y)) ] }

(* Field definitions are semicolon-separated or -terminated. *)

%inline data_fields_def:
  fss = separated_or_terminated_list(SEMI, data_field_def)
    { List.flatten fss }

(* A list of field definitions is optionally followed with BAR and a
   permission. *)

data_type_def_branch_content:
  fs = data_fields_def
    { fs }
| fs = data_fields_def BAR perm = very_loose_type
    { fs @ [ FieldPermission perm ] }

(* A branch in a data type definition is a constructor application,
   where, within the braces, we have the above content. This is also
   the syntax of structural permissions. *)

%inline data_type_def_branch:
  dfs = generic_datacon_application(data_type_def_branch_content)
    { dfs }

%inline data_type_def_lhs:
  DATA tbs = iterated_type_type_application(variable, atomic_type_binding)
    { tbs }

%inline data_type_def_rhs:
  bs = separated_or_preceded_list(BAR, data_type_def_branch)
    { bs }

%inline adopts_clause:
  ADOPTS t = arbitrary_type
    { t }

%inline data_type_flag:
| (* nothing *)
    { Duplicable }
| MUTABLE
    { Exclusive }

%inline optional_kind_annotation:
| (* nothing *)
    { KType }
| COLONCOLON k = kind
    { k }

%inline fact_conditions:
| (* nothing *)
    { [] }
| DUPLICABLE t = atomic_type DBLARROW
    { [t] }
(* TEMPORARY la syntaxe de fact_conditions/fact me semble trop restrictive?
   et pourquoi n'est-elle pas partagée avec mode_constraint? *)

fact:
| FACT tup = fact_conditions DUPLICABLE t = atomic_type
    { FDuplicableIf (tup, t) }
| FACT EXCLUSIVE t = atomic_type
    { FExclusive t }

data_type_def:
| flag = data_type_flag lhs = data_type_def_lhs EQUAL rhs = data_type_def_rhs
  a = adopts_clause?
    { Concrete (flag, lhs, rhs, a) }
| ABSTRACT name = variable params = atomic_type_binding*
  k = optional_kind_annotation f = fact?
    { Abstract ((name, params), k, f) }

%inline data_type_group:
  def = data_type_def
    { DataTypeGroup (($startpos, $endpos), [def]) }

(* A concrete data type is necessarily of kind KTYPE. We do not allow defining
   concrete data types of kind KPERM. In principle, we could allow it. I think
   we can live without it (experience will tell). *)

(* ---------------------------------------------------------------------------- *)

(* Patterns. *)

%inline plocated (X):
| x = X
    { PLocated (x, $startpos, $endpos) }

%inline atomic_pattern:
| p = plocated(raw_atomic_pattern)
    { p }

raw_atomic_pattern:
| LPAREN p = pattern RPAREN
    { p }
| dc = datacon_application(data_field_pattern)
    { PConstruct dc }
| x = variable
    { PVar x }

data_field_pattern:
| f = variable EQUAL p = pattern
    { f, p }
| f = variable
    (* Punning *)
    { f, PVar f }

%inline normal_pattern:
| p = plocated(raw_normal_pattern)
    { p }

raw_normal_pattern:
| p = raw_atomic_pattern
    { p }
| p = normal_pattern COLON t = normal_type
    { PConstraint (p, t) }
| ps = separated_list_of_at_least_two(COMMA, atomic_pattern)
    { PTuple ps }
| p = normal_pattern AS v = variable
    { PAs (p, PVar v) }
(* TEMPORARY wildcards are missing *)
(* TEMPORARY or-patterns are missing *)

%inline pattern:
| p = normal_pattern
    { p }

(* ---------------------------------------------------------------------------- *)

(* Terms. *)

rec_flag:
| REC
    { Recursive }
|
    { Nonrecursive }

%inline elocated (X):
| x = X
    { ELocated (x, $startpos, $endpos) }

(* Main expression rule *)
%inline expression:
| e = elocated(expression_raw)
    { e }

  expression_raw:
  | e1 = everything_except_let_and_semi SEMI e2 = expression
      { ESequence (e1, e2) }
  | LET f = rec_flag declarations = separated_list(AND, inner_declaration) IN e = expression
      { ELet (f, declarations, e) }
  | FUN bs = type_parameters? arg = atomic_type COLON t = normal_type EQUAL e = expression
      { EFun (Option.map_none [] bs, arg, t, e) }
  | e = everything_except_let_and_semi_raw
      { e }

  everything_except_let_and_semi:
  | e = elocated(everything_except_let_and_semi_raw)
      { e }

  everything_except_let_and_semi_raw:
  (* disallow let inside of "then", too fragile *)
  | IF b = explain e1 = expression THEN e2 = everything_except_let_and_semi
      { EIfThenElse (b, e1, e2, ETuple []) }
  | IF b = explain e1 = expression THEN e2 = everything_except_let_and_semi ELSE e3 = everything_except_let_and_semi
      { EIfThenElse (b, e1, e2, e3) }
  (* cannot allow let because right-hand side of let can contain a semi-colon *)
  | e1 = preatomic DOT f = variable LARROW e2 = everything_except_let_and_semi
      { EAssign (e1, mkfield f, e2) }
  | TAGOF e1 = preatomic LARROW d = datacon
      { EAssignTag (e1, mkdatacon d) }
  | TAKE e1 = expression FROM e2 = everything_except_let_and_semi
      { ETake (e1, e2) }
  | GIVE e1 = expression TO e2 = everything_except_let_and_semi
      { EGive (e1, e2) } 
  | es = separated_list_of_at_least_two(COMMA, infix_op)
      { ETuple es }
  | ASSERT t = very_loose_type
      { EAssert t }
  | e = explained_raw
      { e }

  explained_raw:
  | e = infix_op EXPLAIN
      { EExplained e }
  | e = infix_op_raw
      { e }

  %inline infix_op:
  | e = elocated(infix_op_raw)
      { e }

  infix_op_raw:
  | e1 = infix_op o = OPINFIX0 e2 = infix_op
      { mkinfix e1 o e2 }
  | e1 = infix_op EQUAL e2 = infix_op
      { mkinfix e1 "=" e2 }
  | e1 = infix_op o = OPINFIX1 e2 = infix_op
      { mkinfix e1 o e2 }
  | e1 = infix_op o = OPINFIX2 e2 = infix_op
      { mkinfix e1 o e2 }
  | e1 = infix_op o = OPINFIX3 e2 = infix_op
      { mkinfix e1 o e2 }
  | e1 = infix_op STAR e2 = infix_op
      { mkinfix e1 "*" e2 }
  | e1 = infix_op MINUS e2 = infix_op
      { mkinfix e1 "-" e2 }
  (* Whereas the regular prefix operators, represented by the token [OPPREFIX],
     bind very tightly, the unary [MINUS] operator binds more loosely. Here, we
     follow OCaml. The goal is to interpret [f !x] as [f (!x)] and [f -1] as
     [f - 1]. Like OCaml, we allow [-f x], which is interpreted as [-(f x)]. *)
  | MINUS e = app
      { mkinfix (EInt 0) "-" e }
  | e = app_raw
      { e }

  (* Application *)
  %inline app:
  | e = elocated(app_raw)
      { e }

  app_raw:
  | e1 = app e2 = preatomic
      { EApply (e1, e2) }
  | e1 = app LBRACKET ts = separated_nonempty_list(COMMA, app_component) RBRACKET
      { ETApply (e1, ts) }
  | e = preatomic_raw
      { e }

      app_component:
      | t = normal_type
          { Ordered t }
      | v = variable EQUAL t = normal_type
          { Named (v, t) }

  %inline preatomic:
    e = elocated(preatomic_raw)
      { e }

  preatomic_raw:
  | e = preatomic DOT f = variable
      { EAccess (e, mkfield f) }
  | a = atomic_raw
      { a }

  explain:
  |
      { false }
  | EXPLAIN
      { true }

  %inline atomic:
  | e = elocated(atomic_raw)
      { e }

  atomic_raw:
  (* The regular prefix operators, represented by the token [OPPREFIX], bind
     very tightly. Here, we follow OCaml. For instance, [!x.foo] is interpreted
     as [(!x).foo]. Thus, the prefix operators bind more tightly than the dot. *)
  | o = OPPREFIX e = atomic
      { EApply (EVar (Variable.register o), e) }
  | v = variable
      { EVar v }
  | m = module_name COLONCOLON x = variable
      { EQualified (m, x) }
  | i = INT
      { EInt i }
  | FAIL
      { EFail }
  | dc = datacon_application(data_field_assign)
      { EConstruct dc }
  | LPAREN RPAREN
      { ETuple [] }
  | MATCH b = explain e = expression WITH bs = separated_or_preceded_list(BAR, match_branch) END
      { EMatch (b, e, bs) }
  | BEGIN e = expression END
      { e }
  | LPAREN e = infix_op COLON t = arbitrary_type RPAREN
      { EConstraint (e, t) }
  | LPAREN e = expression RPAREN
      { e }

    data_field_assign:
    (* cannot allow let because right-hand side of let can contain a semi-colon *)
    | f = variable EQUAL e = everything_except_let_and_semi
        { f, e }
    | f = variable
        (* Punning *)
        { f, EVar f }

    %inline match_branch:
    (* TEMPORARY I would like to allow more than atomic_pattern here *)
    (* but there is a conflict due to PConstraint *)
    | p = atomic_pattern ARROW e = expression
        { p, e }

(* ---------------------------------------------------------------------------- *)

(* Top-level declarations. *)

%inline dlocated (X):
| x = X
    { DLocated (x, $startpos, $endpos) }

(* A declaration group is a sequence of mutually recursive definitions. *)
declaration_group:
| l = declaration
    { ValueDeclarations [l] }

%inline declaration:
| d = dlocated(decl_raw)
    { d }

(* We use the keyword [val] for top-level declarations. *)
decl_raw:
| VAL flag = rec_flag declarations = separated_list(AND, inner_declaration)
    { DMultiple (flag, declarations) }

(* ---------------------------------------------------------------------------- *)

(* Inner declarations, also used by let-bindings. *)

(* We make a distinction between a single pattern and a function definition. The
 * former encompasses idioms such as [val x,y = ...]. The latter allows one to
 * define a function. There are additional rules that ought to be verified at
 * some point (e.g. only variables are allowed on the left-hand side of a
 * let-rec *)
inner_declaration:
| p = pattern EQUAL e = expression
    { p, e }
| f_name = variable
  bs = type_parameters?
  constraints = loption(mode_constraint)
  arg = atomic_type
  COLON t = normal_type
  EQUAL e = expression
    { PVar f_name,
      EFun (Option.map_none [] bs, TyConstraints (constraints, arg), t, e) }

(* ---------------------------------------------------------------------------- *)

open_directive:
| OPEN m = module_name
    { OpenDirective m }

(* Program units, i.e. module implementations *)

(* Because we don't want to clobber the parser with complicated logic, we first
 * parse each declaration as being in its own group, and the [ParserUtils.group]
 * function will take care of grouping all of them together. This also makes it
 * easier if we are to add more top-level declarations that we might want to
 * group as well. *)
implementation_toplevel:
| group = data_type_group
    { group }
| declarations = declaration_group
    { declarations }
| open_mod = open_directive
    { open_mod }


implementation:
  | bs = implementation_toplevel+ EOF
    { ParserUtils.group bs }

(* ---------------------------------------------------------------------------- *)

(* Module signatures, i.e. interfaces. *)

(* A declaration group is a sequence of mutually recursive definitions. *)
perm_declaration:
| VAL t = raw_anchored_permission
    { PermDeclaration t }
(* TEMPORARY question: why do we use "val x @ int" and not "val x : int"?
   After all, @ is supposed to be used when we are referring to a pre-existing
   name, while : is supposed to be used when we are introducing a new name.
   So COLON would be more appropriate here, wouldn't it? *)

interface_toplevel:
| group = data_type_group
    { group }
| declarations = perm_declaration
    { declarations }
| open_mod = open_directive
    { open_mod }

interface:
  | bs = interface_toplevel+ EOF
    { ParserUtils.group bs }

(* ---------------------------------------------------------------------------- *)

(* Below this line: ideas for the record or for future consideration. *)

(* We have removed arrow kinds because they complicate the inference and
   expression of ``mode facts''. That is, in the presence of type variables of
   higher kinds, it becomes difficult to specify exactly under what conditions
   a type is duplicable, exclusive, or affine. Perhaps the loss of arrow kinds
   will be compensated by introducing a module system (functors, etc.) where
   facts can appear as module components. *)

(* If the [if] construct was closed with [endif], then one could again
   authorize a [let] construct to appear naked within a [then] or [else]
   branch. *)

(* I considered using COMMA for separating conjunction. However, COMMA is
   already used to separate multiple arguments in a type application, so this
   means that parentheses will sometimes be necessary (e.g. when a conjunction
   of permissions is used as an argument in a type application). Even worse,
   COMMA is used in the syntax of tuples, and this leads to conflicts with
   tuple types and multi-argument function types. So, I give up and use a
   dedicated symbol, STAR, for conjunction. Somewhat analogously, yet another
   symbol, BAR, is now used for the conjunction of a type and a permission. *)

(* ---------------------------------------------------------------------------- *)

(* Below this line: things to do. *)

(* TODO *)

(*
   syntax for anonymous sums?
*)

