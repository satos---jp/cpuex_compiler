%{
	open Syntax
	
	let debug expr = 
		expr , 
		(!Syntax.filename,
			(Parsing.symbol_start ()),
			(Parsing.symbol_end ()))

%}

%token <int>    INT
%token <bool>   BOOL 
%token <string> ID
%token <float>  FLOAT
%token LET IN				  
%token PLUS TIMES MINUS DIV
%token FPLUS FTIMES FMINUS FDIV
%token EQ LT LEQ GT GEQ NEQ
%token IF THEN ELSE NOT
%token LPAR RPAR 
%token FUN ARROW
%token REC
%token ALLCREATE
%token DOT COMMA SEMI EOF

%left IN
%right SEMI
%nonassoc LET
%right if_assoc
%right arrow_assoc
%nonassoc tuple_assoc
%left COMMA
%left EQ LT LEQ GT GEQ NEQ
%left PLUS MINUS FPLUS FMINUS
%left TIMES DIV FTIMES FDIV
%left app_assoc  /* appの結合の強さはこれくらいで、の指示 */
%nonassoc NOT
%left DOT
%nonassoc unary_minus

%start toplevel 
%type <Syntax.decl> toplevel
%% 

toplevel:
  | expr EOF { DExpr($1) }
/* global.ml をパースするためのもの */ 
	| decls
		{ DDecl($1) }
;

decls:
	| EOF { [] }
	| LET var EQ expr decls
		{ ($2,$4) :: $5 }
;


/* simple_expr のみが、関数適用に使える。 */

simple_expr:
	| LPAR expr RPAR
		{ $2 }
	| LPAR RPAR
		{ debug (ETuple([])) }
	| BOOL
		{ debug (EConst(CBool $1)) }
	| INT 
		{ debug (EConst(CInt $1)) }
	| FLOAT
		{ debug (EConst(CFloat $1)) }
	| var
		{ debug (EVar($1)) }
	| simple_expr DOT LPAR expr RPAR
		{ debug (EArrRead($1,$4)) }
;

expr:
	| simple_expr
		{ $1 }
	| NOT expr
		{ debug (EOp("not",[$2])) }
/* 
# -(5.4);;
- : float = -5.4
# -(5.4 +. 9.0);;
Error: This expression has type float but an expression was expected of type
         int
なので、これの伝搬をしておく。

また、結合強さはもとの-のままではだめで、 - 1.2 * 3.4 とかが -(1.2*3.4)とかになってしまう
*/
	| MINUS expr
		%prec unary_minus
		{ match $2 with
			| EConst(CFloat(f)),d2 -> EConst(CFloat(-.f)),d2
			| _ ->  debug (EOp("minus",[$2])) }
	| expr PLUS expr              
		{ debug (EOp("add",[$1;$3])) }
	| expr MINUS expr 
		{ debug (EOp("sub",[$1;$3])) }
	| expr TIMES expr 
		{ debug (EOp("mul",[$1;$3])) }
	| expr DIV expr 
		{ debug (EOp("div",[$1;$3])) }
	| expr FPLUS expr              
		{ debug (EOp("fadd",[$1;$3])) }
	| expr FMINUS expr 
		{ debug (EOp("fsub",[$1;$3])) }
	| expr FTIMES expr 
		{ debug (EOp("fmul",[$1;$3])) }
	| expr FDIV expr 
		{ debug (EOp("fdiv",[$1;$3])) }
	| expr EQ expr 
		{ debug (EOp("eq",[$1;$3])) }
	| expr NEQ expr 
		{ debug (EOp("neq",[$1;$3])) }
	| expr LT expr 
		{ debug (EOp("lt",[$1;$3])) }
	| expr LEQ expr 
		{ debug (EOp("leq",[$1;$3])) }
	| expr GT expr 
		{ debug (EOp("gt",[$1;$3])) }
	| expr GEQ expr 
		{ debug (EOp("geq",[$1;$3])) }
	| expr SEMI
		{ debug (EOp("semi",[$1])) }
	| expr SEMI expr 
		{ debug (EOp("semi",[$1;$3])) }
/*
セミコロン1つだけもvalidらしい(本家パーザにはないが)
*/
	| IF expr THEN expr ELSE expr
		%prec if_assoc
		{ debug (EIf($2,$4,$6)) }
	| LET var EQ expr IN expr
		{ debug (ELet($2,$4,$6)) }
	| LET REC rec_vars EQ expr IN expr 
		{  debug (ELetRec(List.hd $3,List.tl $3,$5,$7)) }
/* カリー化できないらしい!! (まあMinCamlプログラミングがつらくなる) */
	| simple_expr app_exprs
		%prec app_assoc
		{ debug (EApp($1,$2)) }
	| tuple_exprs                 
		%prec tuple_assoc
		{ debug (ETuple($1))  }
	| LET LPAR tuple_vars EQ expr IN expr 
		{ debug (ELetTuple($3,$5,$7)) }
	| ALLCREATE simple_expr simple_expr             
		{ debug (EArrCrt($2,$3)) }
	| simple_expr DOT LPAR expr RPAR ARROW expr 
		%prec arrow_assoc
		{ debug (EArrWrite($1,$4,$7)) }  
	| error
    { Syntax.err := ((Parsing.symbol_start ()), (Parsing.symbol_end ()));
    	failwith "mly error" }
/*
    { failwith 
    	
        (Printf.sprintf "parse error near characters %d-%d"
           (Parsing.symbol_start ())
           (Parsing.symbol_end ())) }
*/
;

tuple_exprs:
	| tuple_exprs COMMA expr{ $1 @ [$3] }
	| expr COMMA expr { [$1; $3] }
;


app_exprs:
	| simple_expr app_exprs
		{ $1 :: $2 }
	| simple_expr 
		{ [$1] }
;


tuple_vars:
	| RPAR { [] }
	| var RPAR { [$1] }
	| var COMMA tuple_vars { $1 :: $3 }
;

rec_vars:
	| var rec_vars { $1 :: $2 }
	| var { [$1] } 
;

var:
  | ID { $1 }
;