open Knorm


let clos = ref []

(*
別に型を定義するのが億劫になってきたので
とりあえずKNormでやっていく。
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

