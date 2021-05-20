%option noyywrap

%%

"//".*\n  { } /*Ignore comments*/
"bool"	{ return BOOL; }
"do"	{ return DO; }
"od"	{ return OD; }
"if"	{ return IF; }
"fi"	{ return FI; }
"skip"	{ return SKIP; }
"proc"	{ return PROC; }
"end"	{ return END; }
"var"	{ return VAR; }


":="	{ return ASSIGN; }
"^"	{ return XOR; }
"||"	{ return OR; }
"&&"	{ return AND; }
"!"	{ return NOT; }

[a-z_][a-z0-9_]* { yylval.i = strdup(yytext); return IDENT; }

[	 \n]   { /* ignore */ }

.	{ return *yytext; }

%%

