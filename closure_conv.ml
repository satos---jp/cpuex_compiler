open Knorm
open Syntax

let gencname = let c = ref 0 in (fun () -> c := (!c)+1; Printf.sprintf "@cls_%d" !c)


(*
�ʂɌ^���`����̂������ɂȂ��Ă����̂�
�Ƃ肠����KNorm�ł���Ă����B
*)

(* name list *)
let globals = ref ([] : name list)


type cexp = 
	| CConst of Syntax.const
	| COp        of string * (name list)
	| CLet       of name * cexp * cexp
	| CIf        of comptype * name * name * cexp * cexp
	| CVar       of name
	| CApp       of name * (name list)
	| CTuple     of (name list)
	| CLetTuple  of (name list) * name * cexp
	| CClosure   of name * (name list)

(*
let rec cexp2str ast = 
	match cexp with
	| CConst x -> 
*)

let rec get_fvs ast env = 
	let filter vs = List.filter (fun x -> not (List.mem x env)) vs in
	match ast with
	| CConst _ -> []
	| COp(_,vs) | CTuple vs | CClosure(_,vs) -> filter vs
	| CIf(_,x,y,e1,e2) -> (filter [x;y]) @ (get_fvs e1 env) @ (get_fvs e2 env)
	| CLet(x,e1,e2) -> (get_fvs e1 (x :: env)) @ (get_fvs e2 env)
	| CApp(f,vs) -> filter (f :: vs)
	| CLetTuple(vs,tp,e1) -> (filter [tp]) @ (get_fvs e1 (vs @ env))
	| CVar x -> (filter [x])



let rec remove_closure ast isglobal = 
	match ast with
	| KLetRec(fn,args,e1,e2) -> (
			let te1 = remove_closure e1 false in
			(* e1���ɏo�Ă���A�O���R���̂��̂�������  *)
			let fvs = get_fvs te1 args in
			(* fvs�̂����Aglobals�͏����Ă悢 *) 
			let rfvs = List.filter (fun x -> not (List.mem x (!globals))) fvs in
			(* �����ʓ|�Ȃ̂łƂ肠�����S���N���[�W���ŁB 2�̒l�������Ă����B *)
			let global_name = gencname () in (* global�ł̖��O *)
				globals := global_name :: !globals;
				CLet(fn,CClosure(global_name,rfvs),remove_closure e2 false)
		)
	| KConst(a) -> CConst(a)
	| KOp(a,b) -> COp(a,b)
	| KIfEq(a,b,c,d) -> CIf(CmpEq,a,b,remove_closure c isglobal,remove_closure d isglobal)
	| KIfLeq(a,b,c,d) -> CIf(CmpLt,a,b,remove_closure c isglobal,remove_closure d isglobal)
	| KLet(a,b,c) -> 
		if isglobal then globals := a :: !globals else ();
			CLet(a,remove_closure b false,remove_closure c isglobal)
	| KVar(a) -> CVar(a)
	| KTuple(a) -> CTuple(a)
	| KLetTuple(a,b,c) -> CLetTuple(a,b,remove_closure c isglobal)
	| KApp(a,b) -> CApp(a,b)

(*
���łɁAlet x = (let a = ~~~) in ~~~ -> let a = ~~~ in let x = ~~~ in ~~~ �̕ϊ������Ă���
*)

let conv ast = remove_closure ast true

