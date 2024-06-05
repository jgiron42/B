#include "parser.tab.hpp"
#include <iostream>
#include <fstream>
#include <memory>

int yydebug;

std::shared_ptr<yyLexer>	lexer;
std::shared_ptr<yyParser>	parser;


int main(int argc, char **argv)
{
	std::istream *stream = &std::cin;
	std::ifstream file;
	file.open("/dev/stdin");
	stream = &file;
	if (!file.is_open())
	{
		std::cerr << "error: cant open file: " << "/dev/stdin" << std::endl;
		return 1;
	}
	lexer.reset(new yyLexer(stream));
//	yydebug = 1;
//	std::pair<int, YYSTYPE> ret;
//	while ((ret = lexer.yylex()).first)
//		std::cout << ret.first << std::endl
//	yydebug = 1;
	parser.reset(new yyParser(*lexer));

	std::cout << R"(
.intel_syntax noprefix
.text
)";
	std::cout.flush();

	if (parser->yyparse())
		return 1; // todo error management

}