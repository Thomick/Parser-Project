%define parse.error detailed

%{

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
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

typedef struct expr	// boolean expression
{
	int type;	// TRUE, FALSE, OR, AND, NOT, 0 (variable)
	var *var;
	struct expr *left, *right;
	int value;
} expr;

typedef struct altlist
{
	int type;  // EXPR, ELSE
	struct expr* expr;
	struct stmt* stmt;
	struct altlist* next;
} altlist;

typedef struct stmt	// command
{
	int type;	// ASSIGN, ';', LOOP, BRANCH, PRINT
	var *var;
	expr *expr;
	struct stmt *left, *right;
	struct altlist *altlist;
	struct stmt *next;
} stmt;

typedef struct stmtlist
{
	struct stmt* stmt;
	struct stmtlist* next;
} stmtlist;

typedef struct proc
{
	var *locs;
	stmt *stmt;
	struct proc *next;
} proc;

typedef struct reach
{
	int reached;
	expr *expr;
	struct reach *next;
} reach;
	
typedef struct prog 
{
	proc *proc;
	reach *reach;
} prog;

/****************************************************************************/
/* All data pertaining to the programme are accessible from these two vars. */

var *program_vars;
prog *program;

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

var* concat_var (var *var1, var *var2)
{
	var *v = var1;
	while (v->next) v = v->next;
	v->next = var2;
	return var1;
}

expr* make_expr (int type, var *var, expr *left, expr *right,int value)
{
	expr *e = malloc(sizeof(expr));
	e->type = type;
	e->var = var;
	e->left = left;
	e->right = right;
	e->value = value;
	return e;
}

stmt* make_stmt (int type, var *var, expr *expr,
			stmt *left, stmt *right, altlist *altlist)
{
	stmt *s = malloc(sizeof(stmt));
	s->type = type;
	s->var = var;
	s->expr = expr;
	s->left = left;
	s->right = right;
	s->altlist = altlist;
	return s;
}

altlist* make_altlist (int type,expr *expr, stmt *stmt)
{
	altlist* a = malloc(sizeof(altlist));
	a->type = type;
	a->expr = expr;
	a->stmt = stmt;
	a->next = NULL;
	return a;
}

void make_prog (proc *proc, reach *reach)
{
	program->proc = proc;
	program->reach = reach;
}

proc* make_proc (var *locs, stmt *stmt, proc *next)
{
	proc* pc = malloc(sizeof(proc));
	pc->locs = locs;
	pc->stmt = stmt;
	pc->next = next;
	return pc;
}

reach* make_reach(expr *expr, reach *next)
{
	reach* r = malloc(sizeof(reach));
	r->reached = 0;
	r->expr = expr;
	r->next = next;
}

%}

/****************************************************************************/

/* types used by terminals and non-terminals */

%union {
	char *i;
	var *v;
	expr *e;
	stmt *s;
	altlist *a;
	proc *pc;
	reach *r;
	int in;
}

%type <v> globs globdeclist locs locdeclist 
%type <e> expr
%type <s> stmt assign
%type <a> altlist altlist_wo_else
%type <pc> proclist
%type <r> reachlist

%token DO OD IF FI ELSE SKIP PROC END VAR REACH BREAK ASSIGN GUARD ARROW OR AND XOR NOT PLUS MINUS EQUAL INFERIOR SUPERIOR
%token <i> IDENT
%token <in> NUM

%left ';'

%left OR XOR
%left AND
%right NOT
%left SUPERIOR INFERIOR EQUAL
%left MINUS PLUS

%%
 
prog	: globs proclist reachlist	{ make_prog($2,$3); program_vars = $1; }
     	| proclist reachlist		{ make_prog($1,$2); } 
	| globs proclist		{ make_prog($2,NULL); program_vars = $1; }

globs	: VAR globdeclist ';' globs	{ $$ = concat_var($2,$4); }
        | VAR globdeclist ';'		{ $$ = $2; }

globdeclist	: IDENT			{ $$ = make_ident($1); }
		| globdeclist ',' IDENT	{ ($$ = make_ident($3))->next = $1; }

proclist	: PROC IDENT locs stmt END proclist	{ $$ = make_proc($3,$4,$6); }
	 	| PROC IDENT stmt END proclist		{ $$ = make_proc(NULL,$3,$5); }
		| PROC IDENT locs stmt END	{ $$ = make_proc($3,$4,NULL); }
	 	| PROC IDENT stmt END		{ $$ = make_proc(NULL,$3,NULL); }

locs	: VAR locdeclist ';' locs	{ $$ = concat_var($2,$4); }
        | VAR locdeclist ';'		{ $$ = $2; }

locdeclist	: IDENT			{ $$ = make_ident($1); }
		| locdeclist ',' IDENT	{ ($$ = make_ident($3))->next = $1; }

stmt	: assign
	| stmt ';' stmt	
		{ $$ = make_stmt(';',NULL,NULL,$1,$3,NULL); }
	| DO altlist OD
		{ $$ = make_stmt(DO,NULL,NULL,NULL,NULL,$2); }
	| IF altlist FI {$$ = make_stmt(IF,NULL,NULL,NULL,NULL,$2);}
	| BREAK			{$$ = make_stmt(BREAK,NULL,NULL,NULL,NULL,NULL);}
	| SKIP			{$$ = make_stmt(SKIP,NULL,NULL,NULL,NULL,NULL);}

altlist	: GUARD expr ARROW stmt altlist {$$ = make_altlist(IF,$2,$4)->next = $5;}
	| GUARD expr ARROW stmt	{$$ = make_altlist(IF,$2,$4);}
	| GUARD ELSE ARROW stmt altlist_wo_else {$$ = make_altlist(ELSE,NULL,$4)->next = $5;}
	| GUARD ELSE ARROW stmt {$$ = make_altlist(ELSE,NULL,$4);}

altlist_wo_else : GUARD expr ARROW stmt altlist_wo_else {$$ = make_altlist(IF,$2,$4)->next = $5;}
		| GUARD expr ARROW stmt {$$ = make_altlist(IF,$2,$4);}

assign	: IDENT ASSIGN expr
		{ $$ = make_stmt(ASSIGN,find_ident($1),$3,NULL,NULL,NULL); }

expr	: IDENT		{ $$ = make_expr(0,find_ident($1),NULL,NULL,0); }
	| expr XOR expr	{ $$ = make_expr(XOR,NULL,$1,$3,0); }
	| expr OR expr	{ $$ = make_expr(OR,NULL,$1,$3,0); }
	| expr AND expr	{ $$ = make_expr(AND,NULL,$1,$3,0); }
	| NOT expr	{ $$ = make_expr(NOT,NULL,$2,NULL,0); }
	| expr PLUS expr	{ $$ = make_expr(PLUS,NULL,$1,$3,0); }
	| expr MINUS expr	{ $$ = make_expr(MINUS,NULL,$1,$3,0); }
	| expr EQUAL expr	{ $$ = make_expr(EQUAL,NULL,$1,$3,0); }
	| expr INFERIOR expr	{ $$ = make_expr(INFERIOR,NULL,$1,$3,0); }
	| expr SUPERIOR expr	{ $$ = make_expr(SUPERIOR,NULL,$1,$3,0); }
	| NUM 			{$$ = make_expr(NUM,NULL,NULL,NULL,$1);}

reachlist	: REACH expr reachlist	{ $$ = make_reach($2,$3); }
	  	| REACH expr		{ $$ = make_reach($2,NULL); }

%%

#include "langlex.c"

/****************************************************************************/
/* programme interpreter      :                                             */

int eval (expr *e)
{
	switch (e->type)
	{
		case XOR: return eval(e->left) ^ eval(e->right);
		case OR: return eval(e->left) || eval(e->right);
		case AND: return eval(e->left) && eval(e->right);
		case NOT: return !eval(e->left);
		case PLUS: return eval(e->left)+eval(e->right);
		case MINUS: return eval(e->left)-eval(e->right);
		case EQUAL: return (eval(e->left)==eval(e->right)) ? 1 : 0;
		case INFERIOR: return (eval(e->left)<eval(e->right)) ? 1 : 0;
		case SUPERIOR: return (eval(e->left)>eval(e->right)) ? 1 : 0;
		case NUM: return e->value;
		case 0: return e->var->value;
	}
}

stmt* choose_alt (altlist* l) // TODO
{
	stmtlist* list = NULL;
	int cnt = 0;
	stmt* elsestmt = NULL;
	altlist* cur = l;
	while(cur->next != NULL){
		if(cur->type == ELSE)
			elsestmt = cur->stmt;
		else if(eval(cur->expr)){
			stmtlist* tmp = malloc(sizeof(stmtlist));
			tmp->stmt = cur->stmt;
			tmp->next = list;
			list = tmp;
			cnt = cnt + 1;
		}
		cur = cur->next;
	}
	if (cnt > 0){
		int rnd = rand()%cnt;
		stmtlist* cur = list;
		while(cur->next != NULL && rnd > 0){
			cur = cur->next;
			rnd = rnd - 1;
		}
		return cur->stmt;
	}
	return elsestmt;
}

int count_proc (proc* proc){
	int cnt = 0;
	struct proc* cur = proc;
	while(cur != NULL){
		cur = cur->next;
		cnt = cnt + 1;
	}
	return cnt;
}

proc* get_proc(proc* proc, int n){
	struct proc* cur = proc;
	while(cur->next != NULL && n > 0){
		cur = cur->next;
		n = n - 1;
	}
	return cur;
}

proc* remove_proc(proc* proc, int n){
	struct proc* prec = get_proc(proc,n);
	if (prec != NULL){
		if(n==0)
			return proc->next;
		if(prec->next != NULL)
			prec->next = prec->next->next;
	}
	return proc;
}

void exec_one_step(proc* proc)
{
	stmt* tmp = NULL;
	if(proc->stmt == NULL)
		return;
	switch(proc->stmt->type)
	{
		case ASSIGN:
			proc->stmt->var->value = eval(proc->stmt->expr);
			proc->stmt = proc->stmt->next;
			break;
		case ';':
			proc->stmt->right->next = proc->stmt->next;
			proc->stmt->left->next = proc->stmt->right;
			proc->stmt = proc->stmt->left;
			exec_one_step(proc);
			break;
		case DO:
			tmp = choose_alt(proc->stmt->altlist);
			tmp->next = proc->stmt;
			proc->stmt = tmp;
			break;
		case IF:
			tmp = choose_alt(proc->stmt->altlist);
			tmp->next = proc->stmt->next;
			proc->stmt = tmp;
			break;
		case BREAK:
			tmp = proc->stmt;
			while(tmp->type != DO){
				tmp = tmp->next;
				if(tmp == NULL){
					proc->stmt = NULL;
					return;
				}
			}
			proc->stmt = tmp->next;
			break;
		case SKIP:
			proc->stmt = proc->stmt->next;
	}
}

void eval_reach(reach* r){
	if(r==NULL)
		return;
	if(eval(r->expr))
		r->reached = 1;
}

int execute (prog* prog){
	int cnt = count_proc(prog->proc);
	while(cnt){
		int rnd = rand()%cnt;
		proc* p = get_proc(prog->proc,rnd);
		exec_one_step(p);
		eval_reach(prog->reach);
		if(p->stmt == NULL)
			prog->proc = remove_proc(prog->proc,rnd);
		cnt = count_proc(prog->proc);
	}
}

/****************************************************************************/

int main (int argc, char **argv)
{
	srand(time(NULL));
	if (argc <= 1) { yyerror("no file specified"); exit(1); }
	yyin = fopen(argv[1],"r");
	if (!yyparse()) {
		execute(program);
	}
}
