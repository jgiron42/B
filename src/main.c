#include "parser.tab.h"
#include "stdio.h"


extern FILE *yyin;


int main()
{
	extern int yyparse();

	yyin = stdin;
	if (yyparse())
		return 1; // todo error management

}