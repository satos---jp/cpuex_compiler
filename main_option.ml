let windows = ref false
let files = (ref [] : string list ref)
let nolib = ref false
let verbose = ref false
let tortesia = ref false
let debugmode = ref false

let vprint f s = 
	if !verbose then (print_string (f s); print_newline ()) else () 

let ivprint s = 
	if !verbose then (print_string s; print_newline ()) else () 
