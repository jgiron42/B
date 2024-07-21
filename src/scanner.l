


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
int	parse_literal(const char *s);
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

{D}+|'(\\.|[^\\'])+'				{ yylval.string = strdup(yytext); return CONSTANT; }

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


int	parse_literal(const char *s)
{
	if (s[0] != '\'')
		return -1;
	if (s[1] != '\\')
		return s[1];
	if (s[2] == 'x')
	{
		int n = 0;
		for (int i = 3;s[i] != '\''; i++)
		{
			n *= 16;
			if (isdigit(s[i]))
				n += s[i] - '0';
			else if (islower(s[i]))
				n += s[i] - 'a';
			else if (isupper(s[i]))
				n += s[i] - 'A';
		}
		return n;
	}
	else if (s[2] >= '0' && s[2] <= '8')
	{
		int n = 0;
		int i;
		for (i = 2;s[i] >= '0' && s[i] <= '8'; i++)
			n = n * 8 + s[i] - '0';
		if (s[i] != '\'')
			return -1;
		return n;
	}
	else switch (s[2])
		{
			case '\\':
				return '\\';
			case 'a':
				return '\a';
			case 'b':
				return '\b';
			case 'f':
				return '\f';
			case 'n':
				return '\n';
			case 't':
				return '\t';
			case 'r':
				return '\r';
			case 'v':
				return '\v';
			default:
				return s[2];
		}
}
