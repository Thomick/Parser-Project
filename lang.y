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
	char *varname;
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
	char *varname;
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


void print_vars(var *vars){
	var *v = vars;
	while (v->next) {
		printf("%s",v->name);
		v = v->next;}
	printf("\n");
}

var* make_ident (char *s)
{
	printf("Begin make_ident\n");
	var *v = malloc(sizeof(var));
	v->name = s;
	v->value = 0;	// make variable false initially
	v->next = NULL;
	printf("End make_ident\n");
	return v;
}

var* concat_var (var *var1, var *var2)
{
	printf("Begin concat_var\n");
	var *v = var1;
	while (v->next) {
		v = v->next;}
	v->next = var2;
	printf("End concat_var\n");
	return var1;
}


expr* make_expr (int type,int value, char *varname, expr *left, expr *right)
{
	printf("Begin make_expr\n");
	expr *e = malloc(sizeof(expr));
	e->type = type;
	e->varname = varname;
	e->left = left;
	e->right = right;
	e->value = value;
	printf("End make_expr\n");
	return e;
}

stmt* make_stmt (int type, char *varname, expr *expr,
			stmt *left, stmt *right, altlist *altlist)
{
	printf("Begin make_stmt\n");
	stmt *s = malloc(sizeof(stmt));
	s->type = type;
	s->varname = varname;
	s->expr = expr;
	s->left = left;
	s->right = right;
	s->altlist = altlist;
	printf("End make_stmt\n");
	return s;
}

altlist* make_altlist (int type,expr *expr, stmt *stmt)
{
	printf("Begin make_altlist\n");
	altlist* a = malloc(sizeof(altlist));
	a->type = type;
	a->expr = expr;
	a->stmt = stmt;
	a->next = NULL;
	printf("End make_altlist\n");
	return a;
}

void make_prog (proc *proc, reach *reach)
{
	printf("Begin make_prog\n");
	program = malloc(sizeof(prog));
	program->proc = proc;
	program->reach = reach;
	printf("End make_prog\n");
}

proc* make_proc (var *locs, stmt *stmt, proc *next)
{
	printf("Begin make_proc\n");
	proc* pc = malloc(sizeof(proc));
	pc->locs = locs;
	pc->stmt = stmt;
	pc->next = next;
	printf("End make_proc\n");
	return pc;
}

reach* make_reach(expr *expr, reach *next)
{
	printf("Begin make_reach\n");
	reach* r = malloc(sizeof(reach));
	r->reached = 0;
	r->expr = expr;
	r->next = next;
	printf("End make_reach\n");
	return r;
}

%}

/****************************************************************************/

/* types used by terminals and non-terminals */

%union {
	char *i;
	int n;
	var *v;
	expr *e;
	stmt *s;
	altlist *a;
	proc *pc;
	reach *r;
}

%type <v> dec declist
%type <e> expr
%type <s> stmt assign
%type <a> altlist altlist_wo_else
%type <pc> proclist
%type <r> reachlist

%token DO OD IF FI ELSE SKIP PROC END VAR REACH BREAK ASSIGN GUARD ARROW OR AND XOR NOT PLUS MINUS EQUAL INFERIOR SUPERIOR
%token <i> IDENT
%token <n> CONSTANT

%left ';'

%left OR XOR
%left AND
%right NOT
%left SUPERIOR INFERIOR EQUAL
%left MINUS PLUS

%%
 
prog	: globs proclist reachlist	{  make_prog($2,$3);  }
     	| proclist reachlist		{  make_prog($1,$2); } 
	| globs proclist		{  make_prog($2,NULL);  }

globs : dec {program_vars = $1;}

dec	: VAR declist ';' dec	{ $$ = concat_var($2,$4); }
        | VAR declist ';'		{ $$ = $2; }

declist	: IDENT			{ $$ = make_ident($1); }
		| declist ',' IDENT	{ ($$ = make_ident($3))->next = $1; }

proclist	: PROC IDENT dec stmt END proclist	{ $$ = make_proc($3,$4,$6); }
	 	| PROC IDENT stmt END proclist		{ $$ = make_proc(NULL,$3,$5); }
		| PROC IDENT dec stmt END	{ $$ = make_proc($3,$4,NULL); }
	 	| PROC IDENT stmt END		{ $$ = make_proc(NULL,$3,NULL); }

stmt	: assign
	| stmt ';' stmt	
		{ $$ = make_stmt(';',NULL,NULL,$1,$3,NULL); }
	| DO altlist OD
		{ $$ = make_stmt(DO,NULL,NULL,NULL,NULL,$2); }
	| IF altlist FI {$$ = make_stmt(IF,NULL,NULL,NULL,NULL,$2);}
	| BREAK			{$$ = make_stmt(BREAK,NULL,NULL,NULL,NULL,NULL);}
	| SKIP			{$$ = make_stmt(SKIP,NULL,NULL,NULL,NULL,NULL);}

altlist	: GUARD expr ARROW stmt altlist {($$ = make_altlist(IF,$2,$4))->next = $5;}
	| GUARD expr ARROW stmt	{$$ = make_altlist(IF,$2,$4);}
	| GUARD ELSE ARROW stmt altlist_wo_else {($$ = make_altlist(ELSE,NULL,$4))->next = $5;}
	| GUARD ELSE ARROW stmt {$$ = make_altlist(ELSE,NULL,$4);}

altlist_wo_else : GUARD expr ARROW stmt altlist_wo_else {($$ = make_altlist(IF,$2,$4))->next = $5;}
		| GUARD expr ARROW stmt {$$ = make_altlist(IF,$2,$4);}

assign	: IDENT ASSIGN expr
		{ $$ = make_stmt(ASSIGN,$1,$3,NULL,NULL,NULL); }

expr	: IDENT		{ $$ = make_expr(0,0,$1,NULL,NULL); }
     	| CONSTANT	{ $$ = make_expr(CONSTANT,$1,NULL,NULL,NULL); }
	| expr XOR expr	{ $$ = make_expr(XOR,0,NULL,$1,$3); }
	| expr OR expr	{ $$ = make_expr(OR,0,NULL,$1,$3); }
	| expr AND expr	{ $$ = make_expr(AND,0,NULL,$1,$3); }
	| NOT expr	{ $$ = make_expr(NOT,0,NULL,$2,NULL); }
	| expr PLUS expr	{ $$ = make_expr(PLUS,0,NULL,$1,$3); }
	| expr MINUS expr	{ $$ = make_expr(MINUS,0,NULL,$1,$3); }
	| expr EQUAL expr	{ $$ = make_expr(EQUAL,0,NULL,$1,$3); }
	| expr INFERIOR expr	{ $$ = make_expr(INFERIOR,0,NULL,$1,$3); }
	| expr SUPERIOR expr	{ $$ = make_expr(SUPERIOR,0,NULL,$1,$3); }

reachlist	: REACH expr reachlist	{ $$ = make_reach($2,$3); }
	  	| REACH expr		{ $$ = make_reach($2,NULL); }

%%

#include "langlex.c"

/****************************************************************************/
/* programme interpreter      :   */

var* find_var_from_varlist (char *s,var* vars)
{
	var *v = vars;
	while (v && strcmp(v->name,s)) v = v->next;
	return v;
}

var* find_var (char *s,proc* proc)
{
	var *v;
	if(proc)
		v=find_var_from_varlist(s,proc->locs);
	if(!v)
		v=find_var_from_varlist(s,program_vars);
	if (!v) { yyerror("undeclared variable"); exit(1); }
	return v;
}

int eval (expr *e, proc* proc)
{
	switch (e->type)
	{
		case XOR: return eval(e->left,proc) ^ eval(e->right,proc);
		case OR: return eval(e->left,proc) || eval(e->right,proc);
		case AND: return eval(e->left,proc) && eval(e->right,proc);
		case NOT: return !eval(e->left,proc);
		case PLUS: return eval(e->left,proc)+eval(e->right,proc);
		case MINUS: return eval(e->left,proc)-eval(e->right,proc);
		case EQUAL: return (eval(e->left,proc)==eval(e->right,proc)) ? 1 : 0;
		case INFERIOR: return (eval(e->left,proc)<eval(e->right,proc)) ? 1 : 0;
		case SUPERIOR: return (eval(e->left,proc)>eval(e->right,proc)) ? 1 : 0;
		case CONSTANT: return e->value;
		case 0: return find_var(e->varname,proc)->value;
	}
}

stmt* choose_alt (altlist* l,proc* proc) // TODO
{
	stmtlist* list = NULL;
	int cnt = 0;
	stmt* elsestmt = NULL;
	altlist* cur = l;
	while(cur->next){
		if(cur->type == ELSE)
			elsestmt = cur->stmt;
		else if(eval(cur->expr,proc)){
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
		while(cur->next && rnd > 0){
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
	while(cur){
		cur = cur->next;
		cnt = cnt + 1;
	}
	return cnt;
}

proc* get_proc(proc* proc, int n){
	struct proc* cur = proc;
	while(cur->next && n > 0){
		cur = cur->next;
		n = n - 1;
	}
	return cur;
}

proc* remove_proc(proc* proc, int n){
	struct proc* prec = get_proc(proc,n);
	if (prec){
		if(n==0)
			return proc->next;
		if(prec->next)
			prec->next = prec->next->next;
	}
	return proc;
}

void exec_one_step(proc* proc)
{
	stmt* tmp = NULL;
	if(!proc->stmt)
		return;
	switch(proc->stmt->type)
	{
		case ASSIGN:
			find_var(proc->stmt->varname,proc)->value = eval(proc->stmt->expr,proc);
			proc->stmt = proc->stmt->next;
			break;
		case ';':
			proc->stmt->right->next = proc->stmt->next;
			proc->stmt->left->next = proc->stmt->right;
			proc->stmt = proc->stmt->left;
			exec_one_step(proc);
			break;
		case DO:
			tmp = choose_alt(proc->stmt->altlist,proc);
			tmp->next = proc->stmt;
			proc->stmt = tmp;
			break;
		case IF:
			tmp = choose_alt(proc->stmt->altlist,proc);
			tmp->next = proc->stmt->next;
			proc->stmt = tmp;
			break;
		case BREAK:
			tmp = proc->stmt;
			while(tmp->type != DO){
				tmp = tmp->next;
				if(!tmp){
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

void eval_reach(reach* r,proc* proc){
	if(r==NULL)
		return;
	if(eval(r->expr,proc))
		r->reached = 1;
}

int execute (prog* prog){
	printf("Begin execution");
	int cnt = count_proc(prog->proc);
	while(cnt){
		int rnd = rand()%cnt;
		proc* p = get_proc(prog->proc,rnd);
		exec_one_step(p);
		eval_reach(prog->reach,p);
		if(!p->stmt)
			prog->proc = remove_proc(prog->proc,rnd);
		cnt = count_proc(prog->proc);
	}
}
/****************************************************************************/

int main (int argc, char **argv)
{
	srand(time(NULL));
	//if (argc <= 1) { yyerror("no file specified"); exit(1); }
	//yyin = fopen(argv[1],"r");
	yyin = fopen("progs/sort.prog","r");
	if (!yyparse()) {
		execute(program);
	}
}
