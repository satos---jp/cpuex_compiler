open Knorm


let clos = ref []

(*
�ʂɌ^���`����̂������ɂȂ��Ă����̂�
�Ƃ肠����KNorm�ł���Ă����B
*)

let rec remove_closure ast env = 
	match ast with
	| KLetRec(fn,args,e1,e2) -> (
			let te1 = remove_closure e1 in
			let 
			remove_closure e2
		)
	| KApp(fn,args) -> (
			
		)
	| _ -> ast

let conv x = x

