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
let rec get_fvs ast env = 
	let filter vs = List.filter (fun (x,_) -> not (List.mem x env)) vs in
	(* Printf.printf "Ast ::\n%s\n" (cexp2str ast);
	Printf.printf "Env :: %s\n" (String.concat "," env); *)
	match ast with
	| CConst _ -> []
	| COp(_,vs) | CTuple vs | CClosure(_,vs) -> filter vs
	| CIf(_,x,y,e1,e2) -> (filter [x;y]) @ (get_fvs e1 env) @ (get_fvs e2 env)
	| CLet((x,_),e1,e2) -> (get_fvs e1 env) @ (get_fvs e2 (x :: env))
	| CApp(f,vs) -> filter (f :: vs)
	| CLetTuple(vs,tp,e1) -> (filter [tp]) @ (get_fvs e1 ((List.map fst vs) @ env))
	| CVar x -> (filter [x])
	| CSelfClosure x -> []


let rec unique_name vs =
	match vs with
	| [] -> []
	| (x,dt) :: xs -> 
		let txs = unique_name xs in
			if List.exists (fun (y,_) -> x = y) txs then txs else (x,dt) :: txs

(*
env�ɂ́A���݂�global�ɂȂ����֐��ꗗ�������Ă���B
*)
let rec remove_closure ast add_cls env = 
	match ast with
	| KLetRec((fn,ft),args,e1,e2) -> (
			let te1 = remove_closure e1 add_cls env in
			(* te1���ɏo�Ă���A�O���R���̂��̂��W�߂�  *)
			let fvs = get_fvs te1 (fn :: env @ (List.map fst args) @ global_funcs) in
			(* fvs�̂����Aglobals�͏����Ă悢 *)
			let rfvs = unique_name (List.filter (fun (x,_) -> not (List.mem x (List.map (fun ((x,_),_) -> x) !globals))) fvs) in
			(* �����ʓ|�Ȃ̂łƂ肠�����S���N���[�W���ŁB 2�̒l�������Ă����B *)
			(* rfvs�ɃN���[�W���̂��߂̈����ꗗ�������Ă��āA������K��ɂ���Ă��� *)
			let global_name = gencname () in (* global�ł̖��O *)
			(* ����̓����ŌĂ΂��֐��ɂ́A�Ƃ肠�����S�Ă��̏������{���Ă���(�֐����o�����Ȃ����̂ɂ͖��ʂ���) *)
			(* �N���[�W�����Ɍ����ϐ��͊O���������Ă������� *)
			let to_add_closure = fun x -> CLet((fn,ft),CClosure((global_name,ft),rfvs),add_cls x) in
			(* �ċA�Ăяo���̂��߁A���g�̓���ȃN���[�W�������B��Xedi�œn���B *)
			let tte1 = CLet((fn,ft),CSelfClosure((global_name,ft)),add_cls te1) in
				(* Printf.printf "name %s :: type %s\n" fn (type2str ft); *)
				print_string (String.concat " : " (List.map fst rfvs));
				Printf.printf " %s closfun\n" global_name;
				globals := ((global_name,ft),(rfvs,args,tte1)) :: !globals;
				to_add_closure (remove_closure e2 to_add_closure (fn :: env))
		)
	| KConst(a) -> CConst(a)
	| KOp(a,b) -> COp(a,b)
	| KIfEq(a,b,c,d) -> CIf(CmpEq,a,b,remove_closure c add_cls env,remove_closure d add_cls env)
	| KIfLeq(a,b,c,d) -> CIf(CmpLt,a,b,remove_closure c add_cls env,remove_closure d add_cls env)
	| KLet((a,t),b,c) -> CLet((a,t),remove_closure b add_cls env,remove_closure c add_cls env) (* �����́Aa�͓���Ȃ��Ă����͂�*)
	| KVar(a) -> CVar(a)
	| KTuple(a) -> CTuple(a)
	| KLetTuple(a,b,c) -> CLetTuple(a,b,remove_closure c add_cls env) (* �������Aa�͓���Ȃ��Ă����͂�*)
	| KApp(a,b) -> CApp(a,b)

let conv ast = 
	let ta = remove_closure ast (fun x -> x) [] in (!globals,ta)


