%locations
%define parse.error verbose
%define parse.trace

%{

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

char* fname_src;
extern int yylineno;
void yyerror (const char* s) {
    fflush(stdout);
    fprintf(stderr, "%s\nat %s:%d\n", s, fname_src, yylineno);
}

int yylex();

/***************************************************************************/
/* Data structures for storing a programme.                                */
typedef struct var	// a variable
{
	char *name;
	int value;
	int initialized;
	struct var *next;
} var;

typedef struct expr	// boolean expression
{
	int type;	// TRUE, FALSE, OR, AND, NOT, 0 (variable)
	char *varname;
	struct expr *left, *right;
	int value;
	char *procname, *labelname;
} expr;

typedef struct altlist
{
	int type;  // EXPR, ELSE
	struct expr* expr;
	struct stmt* stmt;
	struct altlist* next;
} altlist;

typedef struct label
{
	char *name;
	struct label *next;
} label;

typedef struct stmt	// command
{
	int type;	// ASSIGN, ';', LOOP, BRANCH, PRINT
	char *varname;
	expr *expr;
	label *label;
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
	char *name;
	var *locs;
	stmt *stmt;
	stmt *start_stmt;
	struct proc *next;
} proc;

typedef struct reach
{
	int reached;
	expr *expr;
	struct reach *next;
	int cnt;
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

var* make_var (char *s)
{
	var *v = malloc(sizeof(var));
	v->name = s;
	v->value = 0;	// make variable false initially
	v->next = NULL;
	v->initialized = 0;
	return v;
}

var* concat_var (var *var1, var *var2)
{
	var *v = var1;
	while (v->next) {
		v = v->next;}
	v->next = var2;
	return var1;
}


expr* make_expr (int type,int value, char *varname, expr *left, expr *right, char *procname, char *labelname)
{
	expr *e = malloc(sizeof(expr));
	e->type = type;
	e->varname = varname;
	e->left = left;
	e->right = right;
	e->value = value;
	e->procname = procname;
	e->labelname = labelname;
	return e;
}

stmt* make_stmt (int type, char *varname, expr *expr,
			stmt *left, stmt *right, altlist *altlist)
{
	stmt *s = malloc(sizeof(stmt));
	s->type = type;
	s->varname = varname;
	s->expr = expr;
	s->left = left;
	s->right = right;
	s->altlist = altlist;
	return s;
}

void add_label (char *labelname, stmt *stmt)
{
	if(!stmt) {
		label *label = malloc(sizeof(label));
		label->name = labelname;
		label->next = stmt->label;
		stmt->label = label;
		add_label (labelname,stmt->left);
		add_label (labelname,stmt->right);
	}
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
	program = malloc(sizeof(prog));
	program->proc = proc;
	program->reach = reach;
}

proc* make_proc (var *locs, stmt *stmt, proc *next)
{
	proc* pc = malloc(sizeof(proc));
	pc->locs = locs;
	pc->stmt = stmt;
	pc->next = next;
	pc->start_stmt = stmt;
	return pc;
}

reach* make_reach(expr *expr, reach *next)
{
	reach* r = malloc(sizeof(reach));
	r->reached = 0;
	r->expr = expr;
	r->next = next;
	r->cnt = 0;
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

%token DO OD IF FI ELSE SKIP PROC END VAR REACH BREAK ASSIGN GUARD ARROW OR AND XOR NOT PLUS MINUS EQUAL INFERIOR SUPERIOR AROBASE
%token <i> IDENT
%token <n> CONSTANT

%left ';'
%right ':'

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

declist	: IDENT			{ $$ = make_var($1); }
	| declist ',' IDENT	{ ($$ = make_var($3))->next = $1; }

proclist	: PROC IDENT dec stmt END proclist	{ $$ = make_proc($3,$4,$6); }
	 	| PROC IDENT stmt END proclist		{ $$ = make_proc(NULL,$3,$5); }
		| PROC IDENT dec stmt END	{ $$ = make_proc($3,$4,NULL); }
	 	| PROC IDENT stmt END		{ $$ = make_proc(NULL,$3,NULL); }

stmt	: assign
     	| IDENT ':' stmt	{ $$ = $3; add_label($1,$$); }
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

expr	: IDENT		{ $$ = make_expr(0,0,$1,NULL,NULL,NULL,NULL); }
     	| CONSTANT	{ $$ = make_expr(CONSTANT,$1,NULL,NULL,NULL,NULL,NULL); }
	| expr XOR expr	{ $$ = make_expr(XOR,0,NULL,$1,$3,NULL,NULL); }
	| expr OR expr	{ $$ = make_expr(OR,0,NULL,$1,$3,NULL,NULL); }
	| expr AND expr	{ $$ = make_expr(AND,0,NULL,$1,$3,NULL,NULL); }
	| NOT expr	{ $$ = make_expr(NOT,0,NULL,$2,NULL,NULL,NULL); }
	| expr PLUS expr	{ $$ = make_expr(PLUS,0,NULL,$1,$3,NULL,NULL); }
	| expr MINUS expr	{ $$ = make_expr(MINUS,0,NULL,$1,$3,NULL,NULL); }
	| expr EQUAL expr	{ $$ = make_expr(EQUAL,0,NULL,$1,$3,NULL,NULL); }
	| expr INFERIOR expr	{ $$ = make_expr(INFERIOR,0,NULL,$1,$3,NULL,NULL); }
	| expr SUPERIOR expr	{ $$ = make_expr(SUPERIOR,0,NULL,$1,$3,NULL,NULL); }
	| '(' expr ')'		{ $$ = $2; }
	| IDENT AROBASE IDENT	{ $$ = make_expr(AROBASE,0,NULL,NULL,NULL,$1,$3);}

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
	var *v = NULL;
	if(proc)
		v=find_var_from_varlist(s,proc->locs);
	if(!v)
		v=find_var_from_varlist(s,program_vars);
	if (!v) { yyerror("undeclared variable"); exit(1); }
	return v;
}

void print_expr(expr *e){
	switch (e->type)
	{
		case XOR: print_expr(e->left); printf("^ "); print_expr(e->right);break;
		case OR: print_expr(e->left); printf("|| ") ;  print_expr(e->right);break;
		case AND: print_expr(e->left); printf("&& "); print_expr(e->right);break;
		case NOT: printf("!"); print_expr(e->left);break;
		case PLUS: print_expr(e->left); printf("+ "); print_expr(e->right);break;
		case MINUS: print_expr(e->left); printf("- "); print_expr(e->right);break;
		case EQUAL: print_expr(e->left); printf("== "); print_expr(e->right);break;
		case INFERIOR: print_expr(e->left); printf("< "); print_expr(e->right);break;
		case SUPERIOR: print_expr(e->left); printf("> "); print_expr(e->right);break;
		case CONSTANT: printf("%d ",e->value);break;
		case AROBASE: printf("%s@%s ",e->procname,e->labelname);break;
		case 0: printf("%s ",e->varname);break;
	}
}

int has_uninit_var (expr *e, proc* proc){
	switch (e->type)
	{
		case XOR: return has_uninit_var(e->left,proc) || has_uninit_var(e->right,proc);
		case OR: return has_uninit_var(e->left,proc) || has_uninit_var(e->right,proc);
		case AND: return has_uninit_var(e->left,proc) || has_uninit_var(e->right,proc);
		case NOT: return has_uninit_var(e->left,proc);
		case PLUS: return has_uninit_var(e->left,proc)||has_uninit_var(e->right,proc);
		case MINUS: return has_uninit_var(e->left,proc)||has_uninit_var(e->right,proc);
		case EQUAL: return has_uninit_var(e->left,proc)||has_uninit_var(e->right,proc);
		case INFERIOR: return has_uninit_var(e->left,proc)||has_uninit_var(e->right,proc);
		case SUPERIOR: return has_uninit_var(e->left,proc)||has_uninit_var(e->right,proc);
		case CONSTANT: return 0;
		case AROBASE: return 0;
		case 0: return !find_var(e->varname,proc)->initialized;
	}
}

int eval_step (expr *e, proc* proc)
{
	switch (e->type)
	{
		case XOR: return eval_step(e->left,proc) ^ eval_step(e->right,proc);
		case OR: return eval_step(e->left,proc) || eval_step(e->right,proc);
		case AND: return eval_step(e->left,proc) && eval_step(e->right,proc);
		case NOT: return !eval_step(e->left,proc);
		case PLUS: return eval_step(e->left,proc)+eval_step(e->right,proc);
		case MINUS: return eval_step(e->left,proc)-eval_step(e->right,proc);
		case EQUAL: return eval_step(e->left,proc)==eval_step(e->right,proc);
		case INFERIOR: return eval_step(e->left,proc)<eval_step(e->right,proc);
		case SUPERIOR: return eval_step(e->left,proc)>eval_step(e->right,proc);
		case CONSTANT: return e->value;
		case 0: return find_var(e->varname,proc)->value;
	}
}

int eval (expr *e, proc* proc){
	if(has_uninit_var(e, proc))
		return 0;
	return eval_step(e, proc);
}

stmt* choose_alt (altlist* l,proc* proc) // TODO
{
	stmtlist* list = NULL;
	int cnt = 0;
	stmt* elsestmt = NULL;
	altlist* cur = l;
	while(cur){
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
		while(cur && rnd > 0){
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
		if(cur->stmt)
			cnt = cnt + 1;
		cur = cur->next;
	}
	return cnt;
}

proc* get_proc(proc* proc, int n){
	struct proc* cur = proc;
	n=n+1;
	while(cur->next){
		if(cur->stmt)
			n = n - 1;
		if(n == 0)
			return cur;
		cur = cur->next;
	}
	return cur;
}

void exec_one_step(proc* proc)
{
	stmt* tmp = NULL;
	var* tmpvar = NULL;
	if(!proc->stmt)
		return;
	switch(proc->stmt->type)
	{
		case ASSIGN:
			tmpvar = find_var(proc->stmt->varname,proc);
			tmpvar->value = eval(proc->stmt->expr,proc);
			tmpvar->initialized = 1;
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
			if(tmp){
				tmp->next = proc->stmt;
				proc->stmt = tmp;
			}else
				proc->stmt = proc->stmt->next;
			break;
		case IF:
			tmp = choose_alt(proc->stmt->altlist,proc);
			if(tmp){
				tmp->next = proc->stmt->next;
				proc->stmt = tmp;
			}else
				proc->stmt = proc->stmt->next;
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

void eval_reach(reach* r){
	if(!r)
		return;
	if(eval(r->expr,NULL))
		r->reached = 1;
	eval_reach(r->next);
}

void update_reach(reach* r){
	if(!r)
		return;
	if(r->reached)
		r->cnt += 1;
	update_reach(r->next);
}

void print_reach(reach* r, int nb_it){
	if(!r)
		return;
	if(r->cnt)
		printf("Reached : ");
	else 
		printf("Unreached : ");
	print_expr(r->expr);
	printf("   (%d/%d)\n",r->cnt,nb_it);
	print_reach(r->next,nb_it);
}

void reset_program(){
	var* curvar = program_vars;
	while (curvar){
		curvar->initialized = 0;
		curvar = curvar->next;
	}
	proc* curproc = program->proc;
	while (curproc){
		curvar = curproc->locs;
		while(curvar){
			curvar->initialized = 0;
			curvar = curvar->next;
		}
		curproc->stmt = curproc->start_stmt;
		curproc = curproc->next;
	}
	reach* curreach = program->reach;
	while(curreach){
		curreach->reached = 0;
		curreach = curreach->next;
	}
}

int execute (){
	reset_program();
	int remaining_steps = 1000;
	eval_reach(program->reach);
	int cnt = count_proc(program->proc);
	while(cnt && remaining_steps){
		int rnd = rand()%cnt;
		proc* p = get_proc(program->proc,rnd);
		exec_one_step(p);
		eval_reach(program->reach);
		cnt = count_proc(program->proc);
		remaining_steps = remaining_steps-1;
	}
	update_reach(program->reach);
}
/****************************************************************************/

int main (int argc, char **argv)
{
	srand(time(NULL));
	if (argc <= 1) { yyerror("no file specified"); exit(1); }
	int nb_it = argc >= 3 ? atoi(argv[2]) : 100;
	int nb_step = argc >= 4 ? atoi(argv[3]) : 1000;
	fname_src = argv[1];
	yyin = fopen(argv[1],"r");
	if (!yyparse()) {
		printf("Begin running the program %d times, over at most %d steps\n", nb_it,nb_step);
		for(int i = 0; i< nb_it; i += 1){
			execute();
		}
		print_reach(program->reach,nb_it);
	}
}
