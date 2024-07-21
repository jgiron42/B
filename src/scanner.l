


D			[0-9]
A			[a-zA-Z_\b]
H			[a-fA-F0-9]
E			[Ee][+-]?{D}+
FS			(f|F|l|L)
IS			(u|U|l|L)*

%{
#include <stdio.h>
#include <ctype.h>
#include "parser.tab.h"

int check_type(char *);
void count(char *yytext);
int yywrap();
extern int				current_label;
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

{A}(({A}|{D})*)			{ yylval.string = strdup(yytext); return NAME; }

[-+]?{D}+|'(\\.|[^\\'])+'				{ yylval.string = strdup(yytext); return CONSTANT; }

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

"=>>"			{ return(RIGHT_OP_ASSIGN); }
"=<<"			{ return(LEFT_OP_ASSIGN); }
"==<"			{ return(LE_OP_ASSIGN); }
"==>"			{ return(GE_OP_ASSIGN); }
"==="			{ return(EQ_OP_ASSIGN); }
"=!="			{ return(NE_OP_ASSIGN); }
"=&"			{ return(AND_ASSIGN); }
"=-"			{ return(SUB_ASSIGN); }
"=+"			{ return(ADD_ASSIGN); }
"=*"			{ return(MUL_ASSIGN); }
"=/"			{ return(DIV_ASSIGN); }
"=%"			{ return(MOD_ASSIGN); }
"=<"			{ return(LESS_ASSIGN); }
"=>"			{ return(GREAT_ASSIGN); }
"=|"			{ return(OR_ASSIGN); }

">>"			{ return(RIGHT_OP); }
"<<"			{ return(LEFT_OP); }
"=<"			{ return(LE_OP); }
"=>"			{ return(GE_OP); }
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