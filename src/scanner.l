D			[0-9]
A			[a-zA-Z_\b]
H			[a-fA-F0-9]
E			[Ee][+-]?{D}+
FS			(f|F|l|L)
IS			(u|U|l|L)*

%{
#define _GNU_SOURCE
#include <stdio.h>
#include <ctype.h>
#include "parser.tab.h"

int check_type(char *);
void count(char *yytext);
int yywrap();
extern int	current_label;
void comment();
%}

%%

\/\*([^*]|\*[^/])*\*\/		{}
\/\/.*\n					{}

"auto"			{ return(AUTO); }
"extrn"			{ return(EXTRN); }

"switch"		{ return(SWITCH); }
"case"			{ return(CASE); }

"if"			{ return(IF); }
"else"			{ return(ELSE); }

"while"			{ return(WHILE); }

"goto"			{ return(GOTO); }

"return"		{ return(RETURN); }

{A}(({A}|{D})*)	{
		yylval.string = strdup(yytext);
		return NAME;
	}

[-+]?{D}+|'(\\.|[^\\'])+'	{
		yylval.string = strdup(yytext);
		return CONSTANT;
	}

\"([^\"\*]|\*n|\*\"|\*\*)*\"	{
		printf(".section .rodata\n");
		printf(".LC%d:\n", current_label);
		printf(".long .LC%d+4\n", current_label);
		printf(".string %s\n", yytext);
		printf(".text\n");
		asprintf(&yylval.string, ".LC%d", current_label);
		current_label++;
		return CONSTANT;
	}

"++"			{ return(INC_OP); }
"--"			{ return(DEC_OP); }

">>"			{ return(RIGHT_OP); }
"<<"			{ return(LEFT_OP); }
"<="			{ return(LE_OP); }
">="			{ return(GE_OP); }
"=="			{ return(EQ_OP); }
"!="			{ return(NE_OP); }
"&"				{ return('&'); }
"!"				{ return('!'); }
"-"				{ return('-'); }
"+"				{ return('+'); }
"*"				{ return('*'); }
"/"				{ return('/'); }
"%"				{ return('%'); }
"<"				{ return('<'); }
">"				{ return('>'); }
"|"				{ return('|'); }

";"				{ return(';'); }
("{"|"<%")		{ return('{'); }
("}"|"%>")		{ return('}'); }
"?"				{ return('?'); }
":"				{ return(':'); }
","				{ return(','); }
"="				{ return('='); }
"("				{ return('('); }
")"				{ return(')'); }
("["|"<:")		{ return('['); }
("]"|":>")		{ return(']'); }

[ \t\v\n\f]		{ }
.			{ return 256; }

%%

int yywrap()
{
	return(1);
}