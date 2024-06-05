


D			[0-9]
A			[a-zA-Z_\b]
H			[a-fA-F0-9]
E			[Ee][+-]?{D}+
FS			(f|F|l|L)
IS			(u|U|l|L)*

%{
#include <stdio.h>
#include <stack>
#include "parser.def.hpp"

int check_type(char *);
void count(char *yytext);
int yywrap();
int	parse_literal(const std::string &s);
extern int				current_label;
void comment();
%}

%%

\/\*([^*]|\*[^/])*\*\/		count(yytext);
\/\/.*\n					count(yytext);

"auto"			{ count(yytext); return(AUTO); }
"extrn"			{ count(yytext); return(EXTRN); }

"switch"		{ count(yytext); return(SWITCH); }
"case"			{ count(yytext); return(CASE); }

"if"			{ count(yytext); return(IF); }
"else"			{ count(yytext); return(ELSE); }

"while"			{ count(yytext); return(WHILE); }

"goto"			{ count(yytext); return(GOTO); }

"return"		{ count(yytext); return(RETURN); }

{A}(({A}|{D})*)			{ count(yytext); return(std::pair{NAME, std::string(yytext)}); }

{D}+				{ count(yytext); return std::pair{CONSTANT, constant_type(uintmax_t(std::stoull(yytext)))}; }
'(\\.|[^\\'])+'		{ count(yytext); return std::pair{CONSTANT, constant_type(uintmax_t(parse_literal(yytext)))};}
\"([^\"\*]|\*n|\*\"|\*\*)*\"	{
		count(yytext);
		printf(".section .rodata\n");
		printf(".LC%d:\n", current_label);
		printf(".long .LC%d+4\n", current_label);
		printf(".string %s\n", yytext);
		printf(".text\n");
		return std::pair{CONSTANT, constant_type(std::string(".LC") + std::to_string(current_label++))};
	}

"++"			{ count(yytext); return(INC_OP); }
"--"			{ count(yytext); return(DEC_OP); }

"=>>"			{ count(yytext); return(RIGHT_OP_ASSIGN); }
"=<<"			{ count(yytext); return(LEFT_OP_ASSIGN); }
"==<"			{ count(yytext); return(LE_OP_ASSIGN); }
"==>"			{ count(yytext); return(GE_OP_ASSIGN); }
"==="			{ count(yytext); return(EQ_OP_ASSIGN); }
"=!="			{ count(yytext); return(NE_OP_ASSIGN); }
"=&"			{ count(yytext); return(AND_ASSIGN); }
"=-"			{ count(yytext); return(SUB_ASSIGN); }
"=+"			{ count(yytext); return(ADD_ASSIGN); }
"=*"			{ count(yytext); return(MUL_ASSIGN); }
"=/"			{ count(yytext); return(DIV_ASSIGN); }
"=%"			{ count(yytext); return(MOD_ASSIGN); }
"=<"			{ count(yytext); return(LESS_ASSIGN); }
"=>"			{ count(yytext); return(GREAT_ASSIGN); }
"=|"			{ count(yytext); return(OR_ASSIGN); }

">>"			{ count(yytext); return(RIGHT_OP); }
"<<"			{ count(yytext); return(LEFT_OP); }
"=<"			{ count(yytext); return(LE_OP); }
"=>"			{ count(yytext); return(GE_OP); }
"=="			{ count(yytext); return(EQ_OP); }
"!="			{ count(yytext); return(NE_OP); }
"&"				{ count(yytext); return('&'); }
"!"				{ count(yytext); return('!'); }
"-"				{ count(yytext); return('-'); }
"+"				{ count(yytext); return('+'); }
"*"				{ count(yytext); return('*'); }
"/"				{ count(yytext); return('/'); }
"%"				{ count(yytext); return('%'); }
"<"				{ count(yytext); return('<'); }
">"				{ count(yytext); return('>'); }
"|"				{ count(yytext); return('|'); }


";"				{ count(yytext); return(';'); }
("{"|"<%")		{ count(yytext); return('{'); }
("}"|"%>")		{ count(yytext); return('}'); }
"?"				{ count(yytext); return('?'); }
":"				{ count(yytext); return(':'); }
","				{ count(yytext); return(','); }
"="				{ count(yytext); return('='); }
"("				{ count(yytext); return('('); }
")"				{ count(yytext); return(')'); }
("["|"<:")		{ count(yytext); return('['); }
("]"|":>")		{ count(yytext); return(']'); }

[ \t\v\n\f]		{ count(yytext); }
.			{ count(yytext); return error; }

%%

int yywrap()
{
	return(1);
}


int old_column = 0;
int column = 0;
int line = 0;
std::string	current_line;

void count(char *yytext)
{
	int i;

	current_line.append(yytext);
	while (current_line.find('\n') != std::string::npos && current_line.find('\n') != current_line.size() - 1)
		current_line.erase(0, current_line.find('\n') + 1);
	old_column = column;
	for (i = 0; yytext[i] != '\0'; i++)
		if (yytext[i] == '\n')
		{
			column = 0;
			line++;
		}
		else if (yytext[i] == '\t')
			column += 8 - (column % 8);
		else
			column++;
}

extern std::shared_ptr<yyLexer> lexer;

void	finish_line()
{
	std::stack<char> unput_stack;
	while (!current_line.ends_with('\n'))
	{
		char c = lexer->input();
		current_line.push_back(c);
		unput_stack.push(c);
	}
	for (;!unput_stack.empty();unput_stack.pop())
		lexer->unput(unput_stack.top());
}


int	parse_literal(const std::string &s)
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
