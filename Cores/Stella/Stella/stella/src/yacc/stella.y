%{
#include <stdio.h>

Expression* lastExp = nullptr;

#define YYERROR_VERBOSE 1

/* dump Expression stack during parsing? */
#define DEBUG_EXP 0

int yylex();
char *yytext;

void yyerror(const char *e) {
	//if(DEBUG_EXP) fprintf(stderr, "%s at token \"%s\"\n", e, yytext);
	if(DEBUG_EXP) fprintf(stderr, "%s\n", e);
	errMsg = e;

	// be extra paranoid about deletion
	if(lastExp && reinterpret_cast<Expression*>(lastExp))
		delete lastExp;

	lastExp = nullptr;
}

%}

%union {
	int val;
	char* Equate;
	CartMethod cartMethod;
	CpuMethod cpuMethod;
	RiotMethod riotMethod;
	TiaMethod tiaMethod;
	Expression* exp;
	char* DefinedFunction;
}

/* Terminals */
%token <val> NUMBER
%token <val> ERR
%token <Equate> EQUATE
%token <cartMethod> CART_METHOD
%token <cpuMethod>  CPU_METHOD
%token <riotMethod> RIOT_METHOD
%token <tiaMethod>  TIA_METHOD
%token <DefinedFunction> FUNCTION

/* Non-terminals */
%type <exp> expression

/* Operator associativity and precedence */
%left '-' '+'
%left '*' '/' '%'
%left LOG_OR
%left LOG_AND
%left LOG_NOT
%left '|' '^'
%left '&'
%left SHR SHL
%nonassoc '<' '>' GTE LTE NE EQ
%nonassoc DEREF
%nonassoc UMINUS
%nonassoc '['


%%
statement:	expression { if(DEBUG_EXP) fprintf(stderr, "\ndone\n"); result.exp = $1; }
	;

expression:	expression '+' expression { if(DEBUG_EXP) fprintf(stderr, " +"); $$ = new PlusExpression($1, $3); lastExp = $$; }
	|	expression '-' expression { if(DEBUG_EXP) fprintf(stderr, " -"); $$ = new MinusExpression($1, $3); lastExp = $$; }
	|	expression '*' expression { if(DEBUG_EXP) fprintf(stderr, " *"); $$ = new MultExpression($1, $3); lastExp = $$; }
	|	expression '/' expression { if(DEBUG_EXP) fprintf(stderr, " /"); $$ = new DivExpression($1, $3); lastExp = $$; }
	|	expression '%' expression { if(DEBUG_EXP) fprintf(stderr, " %%"); $$ = new ModExpression($1, $3);  lastExp = $$; }
	|	expression '&' expression { if(DEBUG_EXP) fprintf(stderr, " &"); $$ = new BinAndExpression($1, $3); lastExp = $$; }
	|	expression '|' expression { if(DEBUG_EXP) fprintf(stderr, " |"); $$ = new BinOrExpression($1, $3); lastExp = $$; }
	|	expression '^' expression { if(DEBUG_EXP) fprintf(stderr, " ^"); $$ = new BinXorExpression($1, $3); lastExp = $$; }
	|	expression '<' expression { if(DEBUG_EXP) fprintf(stderr, " <"); $$ = new LessExpression($1, $3); lastExp = $$; }
	|	expression '>' expression { if(DEBUG_EXP) fprintf(stderr, " >"); $$ = new GreaterExpression($1, $3); lastExp = $$; }
	|	expression GTE expression { if(DEBUG_EXP) fprintf(stderr, " >="); $$ = new GreaterEqualsExpression($1, $3); lastExp = $$; }
	|	expression LTE expression { if(DEBUG_EXP) fprintf(stderr, " <="); $$ = new LessEqualsExpression($1, $3); lastExp = $$; }
	|	expression NE  expression { if(DEBUG_EXP) fprintf(stderr, " !="); $$ = new NotEqualsExpression($1, $3); lastExp = $$; }
	|	expression EQ  expression { if(DEBUG_EXP) fprintf(stderr, " =="); $$ = new EqualsExpression($1, $3); lastExp = $$; }
	|	expression SHR expression { if(DEBUG_EXP) fprintf(stderr, " >>"); $$ = new ShiftRightExpression($1, $3); lastExp = $$; }
	|	expression SHL expression { if(DEBUG_EXP) fprintf(stderr, " <<"); $$ = new ShiftLeftExpression($1, $3); lastExp = $$; }
	|	expression LOG_OR expression { if(DEBUG_EXP) fprintf(stderr, " ||"); $$ = new LogOrExpression($1, $3); lastExp = $$; }
	|	expression LOG_AND expression { if(DEBUG_EXP) fprintf(stderr, " &&"); $$ = new LogAndExpression($1, $3); lastExp = $$; }
	|	'-' expression %prec UMINUS	{ if(DEBUG_EXP) fprintf(stderr, " U-"); $$ = new UnaryMinusExpression($2); lastExp = $$; }
	|	'~' expression %prec UMINUS	{ if(DEBUG_EXP) fprintf(stderr, " ~"); $$ = new BinNotExpression($2); lastExp = $$; }
	|	'!' expression %prec UMINUS	{ if(DEBUG_EXP) fprintf(stderr, " !"); $$ = new LogNotExpression($2); lastExp = $$; }
	|	'*' expression %prec DEREF { if(DEBUG_EXP) fprintf(stderr, " U*"); $$ = new ByteDerefExpression($2); lastExp = $$; }
	|	'@' expression %prec DEREF { if(DEBUG_EXP) fprintf(stderr, " U@"); $$ = new WordDerefExpression($2); lastExp = $$; }
	|	'<' expression { if(DEBUG_EXP) fprintf(stderr, " U<");  $$ = new LoByteExpression($2);  lastExp = $$; }
	|	'>' expression { if(DEBUG_EXP) fprintf(stderr, " U>");  $$ = new HiByteExpression($2);  lastExp = $$; }
	|	'(' expression ')'	{ if(DEBUG_EXP) fprintf(stderr, " ()"); $$ = $2; lastExp = $$; }
	|	expression '[' expression ']' { if(DEBUG_EXP) fprintf(stderr, " []"); $$ = new ByteDerefOffsetExpression($1, $3); lastExp = $$; }
	|	NUMBER { if(DEBUG_EXP) fprintf(stderr, "const %d", $1); $$ = new ConstExpression($1); lastExp = $$; }
	|	EQUATE { if(DEBUG_EXP) fprintf(stderr, "equate %s", $1); $$ = new EquateExpression($1); lastExp = $$; }
	|	CPU_METHOD { if(DEBUG_EXP) fprintf(stderr, " (CpuMethod)"); $$ = new CpuMethodExpression($1); lastExp = $$; }
	|	CART_METHOD { if(DEBUG_EXP) fprintf(stderr, " (CartMethod)"); $$ = new CartMethodExpression($1); lastExp = $$; }
	|	RIOT_METHOD { if(DEBUG_EXP) fprintf(stderr, " (RiotMethod)"); $$ = new RiotMethodExpression($1); lastExp = $$; }
	|	TIA_METHOD { if(DEBUG_EXP) fprintf(stderr, " (TiaMethod)"); $$ = new TiaMethodExpression($1); lastExp = $$; }
	|	FUNCTION { if(DEBUG_EXP) fprintf(stderr, " (DefinedFunction)"); $$ = new FunctionExpression($1); lastExp = $$; }
	|  ERR { if(DEBUG_EXP) fprintf(stderr, " ERR: "); yyerror((const char*)"Invalid label or constant"); return 1; }
	;
%%
