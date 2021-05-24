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
// Modify parsing error message
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
	int type;	// TRUE, FALSE, OR, AND, NOT, 0 (variable), EQUAL, INFERIOR, SUPERIOR, AROBASE
	char *varname;
	struct expr *left, *right;
	int value;
	char *procname, *labelname;
} expr;

typedef struct altlist	// List of alternatives in a branchment (if or do)
{
	int type;  // EXPR, ELSE
	struct expr* expr;
	struct stmt* stmt;
	struct altlist* next;
} altlist;

typedef struct label	// Label for a statement
{
	char *name;
	struct label *next;	// Can be linked
} label;

typedef struct stmt	// command
{
	int type;	// ASSIGN, ';', DO, IF, BREAK, SKIP
	char *varname;
	expr *expr;
	label *label;
	struct stmt *left, *right;
	struct altlist *altlist;
	struct stmt *next;
} stmt;

typedef struct proc	// Process
{
	char *name;
	var *locs;	// Local variables
	stmt *stmt;
	stmt *start_stmt;	// Store a pointer to the original statement so the process can be reset
	struct proc *next;
} proc;

typedef struct reach	// Specification
{
	int reached;
	expr *expr;
	struct reach *next;
	int cnt;	// Count the number of times the condition was verified among all executions
} reach;
	
typedef struct prog 	// Program
{
	proc *proc;
	reach *reach;
} prog;

/****************************************************************************/
/* All data pertaining to the programme are accessible from these two vars. */

var *program_vars;
prog *program;

/****************************************************************************/
/* Functions for setting up data structures at parse time.                 */

var* make_var (char *s)
{
	var *v = malloc(sizeof(var));
	v->name = s;
	v->value = 0;
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
	s->label = NULL;
	return s;
}

void add_label (char *labelname, stmt *stmt)
{
	if(stmt) {
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

proc* make_proc (var *locs, stmt *stmt, proc *next, char *name)
{
	proc* pc = malloc(sizeof(proc));
	pc->locs = locs;
	pc->stmt = stmt;
	pc->next = next;
	pc->start_stmt = stmt;
	pc->name = name;
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

%right ':'
%left ';'

%left OR XOR
%left AND
%right NOT
%left SUPERIOR INFERIOR EQUAL
%left MINUS PLUS

%%
 
prog	: dec proclist reachlist	{ program_vars = $1; make_prog($2,$3);  }
     	| proclist reachlist		{  make_prog($1,$2); } 
	| dec proclist		{ program_vars = $1; make_prog($2,NULL);  }

dec	: VAR declist ';' dec	{ $$ = concat_var($2,$4); }
        | VAR declist ';'		{ $$ = $2; }

declist	: IDENT			{ $$ = make_var($1); }
	| declist ',' IDENT	{ ($$ = make_var($3))->next = $1; }

proclist	: PROC IDENT dec stmt END proclist	{ $$ = make_proc($3,$4,$6,$2); }
	 	| PROC IDENT stmt END proclist		{ $$ = make_proc(NULL,$3,$5,$2); }
		| PROC IDENT dec stmt END	{ $$ = make_proc($3,$4,NULL,$2); }
	 	| PROC IDENT stmt END		{ $$ = make_proc(NULL,$3,NULL,$2); }

stmt	: assign
     	| IDENT ':' stmt	{ add_label($1,$3); $$ = $3; }
	| stmt ';' stmt	
		{ $$ = make_stmt(';',NULL,NULL,$1,$3,NULL); }
	| DO altlist OD
		{ $$ = make_stmt(DO,NULL,NULL,NULL,NULL,$2); }
	| IF altlist FI {$$ = make_stmt(IF,NULL,NULL,NULL,NULL,$2);}
	| BREAK			{$$ = make_stmt(BREAK,NULL,NULL,NULL,NULL,NULL);}
	| SKIP			{$$ = make_stmt(SKIP,NULL,NULL,NULL,NULL,NULL);}

altlist	: GUARD expr ARROW stmt altlist {($$ = make_altlist(IF,$2,$4))->next = $5;}		// List of alternatives after a DO or a IF token
	| GUARD expr ARROW stmt	{$$ = make_altlist(IF,$2,$4);}
	| GUARD ELSE ARROW stmt altlist_wo_else {($$ = make_altlist(ELSE,NULL,$4))->next = $5;}
	| GUARD ELSE ARROW stmt {$$ = make_altlist(ELSE,NULL,$4);}

altlist_wo_else : GUARD expr ARROW stmt altlist_wo_else {($$ = make_altlist(IF,$2,$4))->next = $5;}	// Allows to only have one ELSE alternative
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
	| IDENT AROBASE IDENT	{ $$ = make_expr(AROBASE,0,NULL,NULL,NULL,$1,$3);}	// Condition on a label

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

// Find a variable from its name (global or local for the process proc)
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

// Print an expression
void print_expr(expr *e){
	switch (e->type)
	{
		case XOR: print_expr(e->left); printf("^ "); print_expr(e->right);break;
		case OR: print_expr(e->left); printf("|| ") ;  print_expr(e->right);break;
		case AND: print_expr(e->left); printf("&& "); print_expr(e->right);break;
		case NOT: printf("!( "); print_expr(e->left);printf(") ");break;
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

// Test if there is an uninitialized variable in the expression
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

// Test if one of the process current statement labels is name [labelname]
int search_label (proc *proc,char *labelname)
{
	if (!proc || !proc->stmt) return 0;
	label *label = proc->stmt->label;
	while(label && strcmp(label->name,labelname)) label = label->next;
	return (label) ? 1 : 0;
}

// Return the process with the name [procname]
proc* search_proc (char *procname)
{
	proc *proc = program->proc;
	while(proc && strcmp(proc->name,procname)) proc = proc->next;
	return proc;
}

// Test if the process named [procname] is currently at a statement with a label named [labelname]
int eval_label (char *procname, char *labelname)
{
	proc *proc = search_proc(procname);
	return search_label(proc,labelname);
}

// One step of the evaluation
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
		case AROBASE: return eval_label(e->procname,e->labelname);
		case 0: return find_var(e->varname,proc)->value;
	}
}

// Evaluate an expression and return its value
// Return 0 if there is an uninitialized variable in the expression
int eval (expr *e, proc* proc){
	if(has_uninit_var(e, proc))
		return 0;
	return eval_step(e, proc);
}

typedef struct stmtlist // List statements without modifying their next pointer
{
	struct stmt* stmt;
	struct stmtlist* next;
} stmtlist;

// Choose a statement randomly among the alternatives that verified their conditions
stmt* choose_alt (altlist* l,proc* proc)
{
	stmtlist* list = NULL;
	int cnt = 0;
	stmt* elsestmt = NULL;
	altlist* cur = l;
	// Identify the else statement and gather possible statements in a list
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
	if (cnt > 0){ // If there is any verified condition
		int rnd = rand()%cnt;
		stmtlist* cur = list;
		while(cur && rnd > 0){
			cur = cur->next;
			rnd = rnd - 1;
		}
		return cur->stmt;
	}
	// There is no verified condition
	return elsestmt;	// Can be a NULL pointer if there is no else statement
}

// Count the remaining processes
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

// Get the n-th process among the remaining processes (there remain statements to be executed)
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

// Execute one program step in the process proc
void exec_one_step(proc* proc)
{
	stmt* tmp = NULL;
	var* tmpvar = NULL;
	if(!proc->stmt) // Reached the end of the process
		return;
	switch(proc->stmt->type)
	{
		case ASSIGN:
			tmpvar = find_var(proc->stmt->varname,proc);
			tmpvar->value = eval(proc->stmt->expr,proc);
			tmpvar->initialized = 1; // Initialize or update the variable
			proc->stmt = proc->stmt->next; // goto next statement
			break;
		case ';':
			// Add substatements on the process statement stack
			proc->stmt->right->next = proc->stmt->next;
			proc->stmt->left->next = proc->stmt->right;
			proc->stmt = proc->stmt->left;
			exec_one_step(proc); // No step was executed so we call the function again
			break;
		case DO:
			// Add one alternative statement on the process statement stack without removing the loop statement
			tmp = choose_alt(proc->stmt->altlist,proc);
			if(tmp){
				tmp->next = proc->stmt;
				proc->stmt = tmp;
			}else // No condition is met and no else statement so we leave the loop
				proc->stmt = proc->stmt->next;
			break;
		case IF:
			// Add one alternative statement on the process statement stack and remove the if statement
			tmp = choose_alt(proc->stmt->altlist,proc);
			if(tmp){
				tmp->next = proc->stmt->next;
				proc->stmt = tmp;
			}else // No condition is met and no else statement so we do nothing
				proc->stmt = proc->stmt->next;
			break;
		case BREAK:
			tmp = proc->stmt;
			while(tmp->type != DO){ // iterate until the next loop statement
				tmp = tmp->next;
				if(!tmp){
					proc->stmt = NULL;	// There is no more statement in the process stack so the process is ended
					return;
				}
			}
			proc->stmt = tmp->next;
			break;
		case SKIP:
			proc->stmt = proc->stmt->next;
	}
}

// Evaluate if specifications were verified and update their state
void eval_reach(reach* r){
	if(!r)
		return;
	if(eval(r->expr,NULL))
		r->reached = 1;
	eval_reach(r->next);
}

// Update the number of times a specification was verified
// Must be called at the end of an execution
void update_reach(reach* r){
	if(!r)
		return;
	if(r->reached)
		r->cnt += 1;
	update_reach(r->next);
}

// Print how often a specification was met 
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

// Resets the program to a state from which it can be run again
// But doesn't erase some data such as the number of time where a program reached a certain state
void reset_program(){
	var* curvar = program_vars;
	// Uninitialize global variables
	while (curvar){
		curvar->initialized = 0;
		curvar = curvar->next;
	}
	proc* curproc = program->proc;
	while (curproc){
		curvar = curproc->locs;	
		// Uninitialize local variables 
		while(curvar){
			curvar->initialized = 0;
			curvar = curvar->next;
		}
		curproc->stmt = curproc->start_stmt; // Go back to first statement
		curproc = curproc->next;
	}
	reach* curreach = program->reach;
	// Reset specification but not the counter
	while(curreach){
		curreach->reached = 0;
		curreach = curreach->next;
	}
}

int execute (int max_step){
	reset_program();
	int remaining_steps = max_step;
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
	update_reach(program->reach); // Update reach counter
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
			execute(nb_step);
		}
		print_reach(program->reach,nb_it);
	}
}
