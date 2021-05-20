%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex();

void yyerror(char *s)
{
	fflush(stdout);
	fprintf(stderr, "%s\n", s);
}

/***************************************************************************/
/* Data structures for storing a programme.                                */

typedef struct var	// a variable
{
	char *name;
	int value;
	struct var *next;
} var;

typedef struct varlist	// variable reference (used for print statement)
{
	struct var *var;
	struct varlist *next;
} varlist;

typedef struct expr	// boolean expression
{
	int type;	// TRUE, FALSE, OR, AND, NOT, 0 (variable)
	var *var;
	struct expr *left, *right;
} expr;

typedef struct alt
{
	struct expr* expr;
	struct stmt* stmt;
} alt;

typedef struct altlist
{
	struct alt* alt;
	struct altlist* next;
} altlist;

typedef struct stmt	// command
{
	int type;	// ASSIGN, ';', LOOP, BRANCH, PRINT
	var *var;
	expr *expr;
	struct stmt *left, *right;
	struct varlist *list;
	struct altlist *altlist;
} stmt;

typedef struct stmtlist
{
	struct stmt* stmt;
	struct stmtlist* next;
} stmtlist;

/****************************************************************************/
/* All data pertaining to the programme are accessible from these two vars. */

var *program_vars;
stmt *program_stmts;

/****************************************************************************/
/* Functions for settting up data structures at parse time.                 */

var* make_ident (char *s)
{
	var *v = malloc(sizeof(var));
	v->name = s;
	v->value = 0;	// make variable false initially
	v->next = NULL;
	return v;
}

var* find_ident (char *s)
{
	var *v = program_vars;
	while (v && strcmp(v->name,s)) v = v->next;
	if (!v) { yyerror("undeclared variable"); exit(1); }
	return v;
}

varlist* make_varlist (char *s)
{
	var *v = find_ident(s);
	varlist *l = malloc(sizeof(varlist));
	l->var = v;
	l->next = NULL;
	return l;
}

expr* make_expr (int type, var *var, expr *left, expr *right)
{
	expr *e = malloc(sizeof(expr));
	e->type = type;
	e->var = var;
	e->left = left;
	e->right = right;
	return e;
}

stmt* make_stmt (int type, var *var, expr *expr,
			stmt *left, stmt *right, varlist *list, altlist *altlist)
{
	stmt *s = malloc(sizeof(stmt));
	s->type = type;
	s->var = var;
	s->expr = expr;
	s->left = left;
	s->right = right;
	s->list = list;
	s->altlist = altlist;
	return s;
}

alt* make_alt (expr *expr, stmt *stmt)
{
	alt *a = malloc(sizeof(alt));
	a->expr = expr;
	a->stmt = stmt;
	return a;
}

altlist* make_altlist (expr *expr, stmt *stmt)
{
	altlist* a = malloc(sizeof(altlist));
	a->alt = make_alt(expr,stmt);
	a->next = NULL;
	return a;
}

%}

/****************************************************************************/

/* types used by terminals and non-terminals */

%union {
	char *i;
	var *v;
	varlist *l;
	expr *e;
	stmt *s;
}

%type <v> declist
%type <l> varlist
%type <e> expr
%type <s> stmt assign

%token DO OD IF FI ELSE SKIP PROC END VAR REACH BREAK ASSIGN GUARD ARROW OR AND XOR NOT PLUS MINUS EQUAL INFERIOR SUPERIOR
%token <i> IDENT

%left ';'

%left OR XOR
%left AND
%right NOT

%%
 
prog	: globs proclist reachlist 
     	| proclist reachlist 
	| globs proclist	{ program_stmts = $2; }

globs	: VAR globdeclist ';' globs	{ program_vars = $2; }
        | VAR globdeclist ';'

globdeclist	: IDENT			{ $$ = make_ident($1); }
		| globdeclist ',' IDENT	{ ($$ = make_ident($3))->next = $1; }

proclist	: PROC IDENT locs stmt END
	 	| PROC IDENT stmt END

locs	: VAR locdeclist ';' locs	{ program_vars = $2; }
        | VAR locdeclist ';'

locdeclist	: IDENT			{ $$ = make_ident($1); }
		| locdeclist ',' IDENT	{ ($$ = make_ident($3))->next = $1; }

stmt	: assign
	| stmt ';' stmt	
		{ $$ = make_stmt(';',NULL,NULL,$1,$3,NULL,NULL); }
	| DO altlist OD
		{ $$ = make_stmt(LOOP,NULL,NULL,NULL,NULL,NULL,$2); }
	| IF altlist FI {$$ = make_stmt(BRANCH,NULL,NULL,NULL,NULL,NULL,$2);}
	| BREAK			{$$ = make_stmt(BREAK,NULL,NULL,NULL,NULL,NULL,NULL);}
	| SKIP			{$$ = make_stmt(SKIP,NULL,NULL,NULL,NULL,NULL,NULL);}

altlist	: GUARD expr ARROW stmt altlist
	| GUARD expr ARROW stmt
	| GUARD ELSE ARROW stmt altlist_wo_else
	| GUARD ELSE ARROW stmt

altlist_wo_else : GUARD expr ARROW stmt altlist_wo_else
		| GUARD expr ARROW stmt

assign	: IDENT ASSIGN expr
		{ $$ = make_stmt(ASSIGN,find_ident($1),$3,NULL,NULL,NULL,NULL); }

expr	: IDENT		{ $$ = make_expr(0,find_ident($1),NULL,NULL); }
	| expr XOR expr	{ $$ = make_expr(XOR,NULL,$1,$3); }
	| expr OR expr	{ $$ = make_expr(OR,NULL,$1,$3); }
	| expr AND expr	{ $$ = make_expr(AND,NULL,$1,$3); }
	| NOT expr	{ $$ = make_expr(NOT,NULL,$2,NULL); }
	| expr PLUS expr
	| expr MINUS expr
	| expr EQUAL expr
	| expr INFERIOR expr
	| expr SUPERIOR expr
	
//	| '(' expr ')'	{ $$ = $2; }

reachlist	: REACH expr reachlist
	  	| REACH expr



%%

#include "langlex.c"

/****************************************************************************/
/* programme interpreter      :                                             */

int eval (expr *e)
{
	switch (e->type)
	{
		case TRUE: return 1;
		case FALSE: return 0;
		case XOR: return eval(e->left) ^ eval(e->right);
		case OR: return eval(e->left) || eval(e->right);
		case AND: return eval(e->left) && eval(e->right);
		case NOT: return !eval(e->left);
		case 0: return e->var->value;
	}
}

void print_vars (varlist *l)
{
	if (!l) return;
	print_vars(l->next);
	printf("%s = %c  ", l->var->name, l->var->value? 'T' : 'F');
}

stmt* choose_alt (altlist) // TODO
{
	stmtlist* list = malloc(sizeof(stmtlist));
	int cnt = 0;
	stmt* elsestmt = NULL;
	return list->stmt;
}

void execute (stmt *s)
{
	switch(s->type)
	{
		case ASSIGN:
			s->var->value = eval(s->expr);
			break;
		case ';':
			execute(s->left);
			execute(s->right);
			break;
		case LOOP:
			while (eval(s->expr)) execute(s->left);
			break;
		case PRINT: 
			print_vars(s->list);
			puts("");
			break;
	}
}

/****************************************************************************/

int main (int argc, char **argv)
{
	if (argc <= 1) { yyerror("no file specified"); exit(1); }
	yyin = fopen(argv[1],"r");
	if (!yyparse()) execute(program_stmts);
}
