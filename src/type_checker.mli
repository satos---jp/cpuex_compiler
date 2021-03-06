open Syntax
open Debug

type tyvar = int

type ty =
	| TyInt
	| TyFloat
	| TyNum
	| TyVar of tyvar
	| TyArr of ty
	| TyFun of (ty list) * ty
	| TyTuple of ty list

val type2str : ty -> string

type name = string * (ty * debug_data)

type texp = texp_base * (ty * debug_data)
and texp_base =
  | TConst of const
  | TVar       of name
  | TOp        of optype * (texp list)
  | TIf        of texp * texp * texp
  | TLet       of name * texp * texp
  | TLetRec    of name * (name list) * texp * texp
  | TApp       of texp * (texp list)
  | TTuple     of (texp list)
  | TLetTuple  of (name list) * texp * texp

val global_funcs : unit -> string list

val check : expr -> texp

