open Knorm
open Syntax
open Debug

let gencname = let c = ref 0 in (fun () -> c := (!c)+1; Printf.sprintf "@cls_%d" !c)


(*
�ʂɌ^���`����̂������ɂȂ��Ă����̂�
�Ƃ肠����KNorm�ł���Ă����B
*)


open Type_checker
type name = string * (ty * debug_data)

type cexp = 
	| CConst of Syntax.const
	| COp        of Syntax.optype * (name list)
	| CLet       of name * cexp * cexp
	| CIf        of comptype * name * name * cexp * cexp
	| CVar       of name
	| CApp       of name * (name list)
	| CTuple     of (name list)
	| CLetTuple  of (name list) * name * cexp
	| CClosure   of name * (name list)
	| CSelfClosure of name

type globdef = (name list) * (name list) * cexp

(* name list *)
let globals = ref ([] : (name * globdef) list)

(*
program .. cexp,globdef list 
*)

let name2str (na,(ty,_)) = na ^ " : " ^ (type2str ty)

let vs2str vs = "(" ^ (String.concat " , " (List.map name2str vs)) ^ ")"

let rec cexp2str_base ast d = 
	match ast with
	| CConst x -> [(d,const2str x)]
	| COp(op,vs) -> [(d,(op2str op) ^ (vs2str vs))]
	| CLet(na,e1,e2) -> (d,"Let " ^ (name2str na) ^ " =") :: (cexp2str_base e1 (d+1)) @ [(d,"In")] @ (cexp2str_base e2 (d+1))
	| CIf(ty,a,b,e1,e2) -> (d,"If " ^ (name2str a) ^ " " ^ (comptype2str ty) ^ " " ^ (name2str b) ^ " Then") :: (cexp2str_base e1 (d+1)) @ [(d,"Else")] @ (cexp2str_base e2 (d+1))
	| CVar(x) -> [(d,"Var " ^ (name2str x))]
	| CApp(fn,vs) -> [(d,"App " ^ (name2str fn) ^ (vs2str vs))]
	| CTuple(vs) -> [(d,(vs2str vs))]
	| CLetTuple(vs,tn,e1) -> (d,"Let " ^ (vs2str vs) ^ " = " ^ (name2str tn)) :: [(d,"In")] @ (cexp2str_base e1 (d+1))
	| CClosure(na,vs) -> [(d,"Closure <" ^ (name2str na) ^ "," ^ (vs2str vs) ^ ">")]
	| CSelfClosure(fn) -> [(d,"SelfClosure " ^ (name2str fn))]

let cexp2str ast = 
	let ss = cexp2str_base ast 0 in
		(String.concat "\n" (List.map (fun (d,s) -> (String.make (d*2) ' ') ^ s) ss)) ^ "\n"
		
let def2str (vs1,vs2,e) = "Func " ^ (vs2str vs1) ^ (vs2str vs2) ^ "[\n" ^ (cexp2str e) ^ "]\n"

let clos2str (gs,v) = 
	(String.concat "" (List.map (fun ((x,_),bo) -> x ^ " : " ^ (def2str bo)) (List.rev gs))) 
	^ (cexp2str v) ^ "\n"

(* ast����env�ɂȂ��ϐ���fv�ł��� *)
let rec get_fvs ast (env : string list) = 
	let filter vs = List.filter (fun (x,_) -> not (List.mem x env)) vs in
	(* Printf.printf "Ast ::\n%s\n" (cexp2str ast);
	Printf.printf "Env :: %s\n" (String.concat "," env); *)
	match ast with
	| KConst _ -> []
	| KOp(_,vs) | KTuple vs -> filter vs
	| KIfEq(x,y,e1,e2) | KIfLeq(x,y,e1,e2) -> (filter [x;y]) @ (get_fvs e1 env) @ (get_fvs e2 env)
	| KLet((x,_),e1,e2) -> (get_fvs e1 env) @ (get_fvs e2 (x :: env))
	| KLetRec((na,_) as x,vs,e1,e2) -> (
			(filter [x]) @ (get_fvs e1 (na :: (List.map fst vs) @ env)) @ (get_fvs e2 (na :: env)) 
			(* �֐�����global�ɂȂ�̂Ŏ����Ă��� *)
		)
	| KApp(f,vs) -> filter (f :: vs)
	| KLetTuple(vs,tp,e1) -> (filter [tp]) @ (get_fvs e1 ((List.map fst vs) @ env))
	| KVar x -> (filter [x])

let rec unique_name vs =
	match vs with
	| [] -> []
	| (x,dt) :: xs -> 
		let txs = unique_name xs in
			if List.exists (fun (y,_) -> x = y) txs then txs else (x,dt) :: txs

(*

let ...
  let f p = 
    let g q = 
       x 

�̂Ƃ��Af��x�����炤�K�v������B

let ...
	let x = ...
	let f p = 
	   x ...
	let g q = 
	   f geeg

�̂Ƃ��Ag��x�����炤�K�v������B

�E fn �� e1,e2���ɑ��݂��邩���Ȃ̂ŁAfn�̃N���[�W����e1,e2 �ɍ��B
�E e1,e2���́Aglobal�ɂȂ���̂́A���ŃN���[�W���̊֐����g���Ă���ꍇ�A�錾���ɂ��̊֐��̃N���[�W���������Ă����K�v������B
�E ���̊֐��̃N���[�W���������Ƃɂ��A���̃N���[�W���쐬���ɕK�v�Ȉ����������Ŏ����Ă����K�v������(�܂��͐e���N���[�W����n���΂悢���H)


let ...
	let x = ...
	let f p = 
	   x ...
	let g q = 
	   f ...
	let h r = 
		 g ...

�̂Ƃ��A
g��f�̃N���[�W���������Ƃ��Ă��炤�B
h��g�̃N���[�W���������Ƃ��Ă��炤�B



�Ƃ肠�����A�錾���ɂ����ɃN���[�W���𔭐������āA�Ă�ł���l�ɂ͓K�X���̐l�̃N���[�W�������ɒǉ����Ă����Ƃ悳�����H

*)
let rec remove_closure ast =
	let reccall = remove_closure in
	match ast with
	| KLetRec((fn,ft),args,e1,e2) -> (
			(* ���R�ϐ����W -> closure�ϊ��A���������� *)
			(* te1���ɏo�Ă���A�O���R���̂��̂��W�߂�  *)
			let fvs = unique_name (get_fvs e1 ((List.map fst args) @ global_funcs)) in
			(* fvs�ɃN���[�W���̂��߂̈����ꗗ�������Ă��āA������K��ɂ���Ă��� *)
			let global_name = gencname () in (* global�ł̖��O *)
			(* ����̓����ŌĂ΂��֐��ɂ́A�Ƃ肠�����S�Ă��̏������{���Ă���(�֐����o�����Ȃ����̂ɂ͖��ʂ���) *)
			let to_add_closure = fun x -> CLet((fn,ft),CClosure((global_name,ft),fvs),x) in
			(* t1��ϊ����� *)
			let te1 = to_add_closure (remove_closure e1) in
			(* �ċA�Ăяo���̂��߁A���g�̓���ȃN���[�W�������B��Xedi�œn���B *)
				(* Printf.printf "name %s :: type %s\n" fn (type2str ft); *)
				(* print_string (String.concat " : " (List.map fst rfvs));
				Printf.printf " :: %s .aka %s\n" global_name fn; *)
				globals := ((global_name,ft),(fvs,args,te1)) :: !globals;
				to_add_closure (remove_closure e2)
		)
	| KConst(a) -> CConst(a)
	| KOp(a,b) -> COp(a,b)
	| KIfEq(a,b,c,d) -> CIf(CmpEq,a,b,reccall c,reccall d)
	| KIfLeq(a,b,c,d) -> CIf(CmpLt,a,b,reccall c,reccall d)
	| KLet((a,t),b,c) -> CLet((a,t),reccall b,reccall c)
	| KVar(a) -> CVar(a)
	| KTuple(a) -> CTuple(a)
	| KLetTuple(a,b,c) -> CLetTuple(a,b,reccall c)
	| KApp(a,b) -> CApp(a,b)

let conv ast = 
	let ta = remove_closure ast in (!globals,ta)


