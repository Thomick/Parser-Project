%option noyywrap

%%

"//".*\n  { } /*Ignore comments*/
"do"	{ return DO; }
"od"	{ return OD; }
"if"	{ return IF; }
"fi"	{ return FI; }
"else"	{ return ELSE; }
"skip"	{ return SKIP; }
"proc"	{ return PROC; }
"end"	{ return END; }
"var"	{ return VAR; }
"reach"	{ return REACH; }
"break"	{ return BREAK; }

":="	{ return ASSIGN; }
"::"	{ return GUARD; }
"->"	{ return ARROW; }
"^"	{ return XOR; }
"||"	{ return OR; }
"&&"	{ return AND; }
"!"	{ return NOT; }
"+"	{ return PLUS; }
"-"	{ return MINUS; }
"==" {return EQUAL; }
"<"	{ return INFERIOR; }
">"	{ return SUPERIOR; }

[0-9]+	{ yylval.n = atoi(yytext); return CONSTANT; }
[a-z_][a-z0-9_]* { yylval.i = strdup(yytext); return IDENT; }
("0"|[1-9][0-9]*) { yylval.n = atoi(yytext); return CONSTANT; }

[	 \n]   { /* ignore */ }

.	{ return *yytext; }

%%

