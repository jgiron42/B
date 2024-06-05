

%{
#include <string>
int yyerror(char *s);
int yyerror(const std::string &s);
#include <stdint.h>
#include <memory>
#include <map>
#include <set>
typedef std::variant<std::monostate, std::string, int> var_type;
typedef std::variant<std::string, uintmax_t> constant_type;
extern std::map <std::string, var_type>	local;
extern std::set <std::string>	global;
extern int				current_stack_size;
extern int				current_label;
extern std::string			switch_end;
typedef std::pair<int, int> int_pair;
std::string constant_to_string(const constant_type &c);
%}

%right ELSE
%nonassoc IF

%token AUTO EXTRN SWITCH CASE  WHILE GOTO RETURN

%token <std::string> NAME
%token <std::string> STRING_LITERAL
%token <constant_type> CONSTANT
%left ','
%right  ':' '?'
%right '=' RIGHT_OP_ASSIGN LEFT_OP_ASSIGN LE_OP_ASSIGN GE_OP_ASSIGN EQ_OP_ASSIGN NE_OP_ASSIGN AND_ASSIGN NOT_ASSIGN SUB_ASSIGN ADD_ASSIGN MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN LESS_ASSIGN GREAT_ASSIGN OR_ASSIGN
%left '|'
%left '&'
%left EQ_OP NE_OP
%left '<' '>' GE_OP LE_OP
%left LEFT_OP RIGHT_OP
%left '+' '-'
%left '*' '/' '%'
%nonassoc UMINUS '!'
%left PRE_INC_DEC
%right POST_INC_DEC FUNCTION_CALL
%nonassoc '(' '['

%token DEC_OP INC_OP

%type <int> case_statement rvalue_list _label tmp tmp2
%type <int_pair> ternary
%type <std::string> section_name sym_name vec_name inc_dec


%use_cpp_lex "scanner.yy.hpp"
%variant

%%

program	: definition
	| program definition
	;

definition : var_definition
	| vec_definition
	| fun_definition
	;

var_definition	: sym_name ';' {  printf(".long 0\n"); printf(".text\n"); }
		| sym_name CONSTANT ';' { printf(".long %s\n", constant_to_string($2).c_str()); printf(".text\n"); }
		| sym_name NAME ';' { printf(".long %s\n", $2.c_str()); printf(".text\n"); }
		;

sym_name	: NAME {printf(".section .data\n"); printf("%s:\n", $1.c_str());$$ = $1; global.insert($1);}
		;

vec_name	: sym_name { printf(".long %s + 4\n", $1.c_str()); $$ = $1;}
		;

vec_definition	: vec_name '[' ']' ';' { printf(".text\n"); }
		| vec_name '[' CONSTANT ']' ';' { printf(".space %s, 0\n", constant_to_string($3).c_str()); printf(".text\n"); }
		| vec_name '[' ']' ival_list ';' { printf(".text\n"); }
      		| vec_name '[' CONSTANT ']' ival_list ';' { printf(".if (.-%s) < %s\n", $1.c_str(), constant_to_string($3).c_str()); printf(".space %s-(.-%s) , 0\n", constant_to_string($3).c_str(), $1.c_str()); printf(".endif\n"); printf(".text\n"); }
		;

ival_list	: ival
		| ival_list ',' ival
		;

ival		: CONSTANT {printf(".long %s\n", constant_to_string($1).c_str());}
		| NAME {printf(".long %s\n", $1);}
		;

fun_definition_name	: NAME {
				printf(".text\n.globl %s\n%s:\n", ($1).c_str(), ($1).c_str());
				if ($1 != "main")
					printf(".long %s + 4\n", ($1).c_str());
				printf("enter 0, 0\n");
				global.insert({$1, {}});
				current_stack_size = 0;
                         }
			;

fun_definition	: fun_definition_name '('  ')' {current_stack_size = 0;} statement {printf("leave\nret\n");local.clear();}
		| fun_definition_name '(' parameter_list ')' {current_stack_size = 0;} statement {printf("leave\nret\n");local.clear();}
		;

parameter_list	: NAME {local.insert({$1, current_stack_size-- - 3});}
		| parameter_list ',' NAME {local.insert({$3, current_stack_size-- - 3});}
		;

statement	: AUTO auto_var_list ';' statement
		| EXTRN extrn_var_list ';' statement
		| NAME ':' {printf(".L%d\n", current_label++);} statement
		| case_statement
		| '{' statement_list '}'
		| if_statement
		| while_statement
		| SWITCH rvalue statement
		| GOTO rvalue ';' {printf("jmp eax\n");}
		| RETURN ';' {printf("leave\nret\n");}
		| RETURN '(' rvalue ')' ';' {printf("leave\nret\n");}
		| ';'
		| rvalue ';'
		;

case_statement: CASE CONSTANT ':' _label
		{
			printf("cmp eax %d\n", $2);
			printf("jne .L%d\n", $4);
		} statement {
			printf(".L%d:", $4);
		}
		;

_label		: {$$ = current_label++;}
		;

_if_goto	: {
			printf("cmp eax, 0\n");
			printf("je .L%d\n", $<int>0);
		}
		;

if_statement	: IF '(' rvalue ')' _label _if_goto statement {printf(".L%d:\n", $5);}
		| IF '(' rvalue ')' _label _if_goto statement ELSE _label {printf("jmp .L%d\n", $9); printf(".L%d:\n", $5);} statement {printf(".L%d:\n", $9);}
		;

tmp		: _label {printf(".L%d:\n", $1);}
		;

tmp2		: _label {
				printf("cmp eax, 0\n");
				printf("je .L%d\n", $1);
                         }
                ;

while_statement	: WHILE tmp '(' rvalue ')' tmp2 statement
                                             {printf("jmp .L%d\n", $2);printf(".L%d:\n", $6);}
		;

statement_list	: statement
		| statement_list statement
		;

auto_var_list	: name_init
		| auto_var_list ',' name_init
		;

name_init	: NAME {local.insert({$1, current_stack_size++});printf("push  0\n");} /*todo check duplicate*/
		| NAME CONSTANT {local.insert({$1, current_stack_size++});printf("push  %s\n", constant_to_string($2).c_str());}
		;

extrn_var_list	: NAME {local.insert({$1, {}});}
		| extrn_var_list ',' NAME {local.insert({$3, {}});}
		;

rvalue		: '(' rvalue ')'
		| lvalue {printf("mov eax, [eax]\n");}
		| CONSTANT {printf("mov eax, %s\n", constant_to_string($1).c_str());}
		| assignment_expression
		| inc_dec lvalue %prec PRE_INC_DEC
		{
			printf("mov ebx, [eax]\n");
			printf("%s ebx, 1\n", $1.c_str());
			printf("mov [eax], ebx\n");
			printf("mov eax, ebx\n");
		}
		| lvalue inc_dec %prec POST_INC_DEC
		{
			printf("mov ebx, [eax]\n");
			printf("mov ecx, ebx\n");
			printf("%s ebx, 1\n", $2.c_str());
			printf("mov [eax], ebx\n");
			printf("mov eax, ecx\n");
		}
		| unary_expression
		| '&' lvalue {}
		| binary_expression
		| ternary
		| rvalue '(' ')' %prec FUNCTION_CALL {printf("call eax\n");}
		| rvalue '(' rvalue_list ')' %prec FUNCTION_CALL {

		 printf("push eax\n");
		 const int operand_count = $3 + 1;
		 for (int i = 0; i < operand_count / 2; i++)
		 {
		 	printf("mov ebx, [esp+%d]\n", i * 4);
		 	printf("mov ecx, [esp+%d]\n", (operand_count - i - 1) * 4);
		 	printf("mov [esp+%d], ebx\n", (operand_count - i - 1) * 4);
		 	printf("mov [esp+%d], ecx\n", i * 4);
		 }
		 printf("pop eax\n");
		 printf("call eax\n");
		 printf("add esp, %d\n", $3 * 4);
		 }
		;

param		: _push_eax rvalue
		;
rvalue_list	: param {$$ = 1;}
		| rvalue_list ',' param {$$ = $1 + 1;}
		;

ternary		: rvalue '?' { $<int_pair>$.first = current_label++; $<int_pair>$.second = current_label++;printf("cmp eax, 0\n");printf("je .L%d\n", $<int_pair>$.first);} rvalue ':' {printf("jmp .L%d\n", $<int_pair>3.second);printf(".L%d:\n", $<int_pair>3.first);} rvalue {printf(".L%d:\n", $<int_pair>3.second);}
		;

assignment_expression	: lvalue '=' _push_eax rvalue {printf("pop ebx\n"); printf("mov [ebx], eax\n");}
			| lvalue RIGHT_OP_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("mov ecx, eax\n"); printf("mov eax, [ebx]\n"); printf("shr eax, cl\n"); printf("mov [ebx], eax\n"); }
			| lvalue LEFT_OP_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("mov ecx, eax\n"); printf("mov eax, [ebx]\n"); printf("shl eax, cl\n"); printf("mov [ebx], eax\n"); }
			| lvalue LE_OP_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("cmp eax, [ebx]\n"); printf("setle al\n"); printf("movzx eax, al\n"); printf("mov [ebx], eax\n");}
			| lvalue GE_OP_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("cmp eax, [ebx]\n"); printf("setge al\n"); printf("movzx eax, al\n"); printf("mov [ebx], eax\n");}
			| lvalue EQ_OP_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("cmp eax, [ebx]\n"); printf("sete al\n"); printf("movzx eax, al\n"); printf("mov [ebx], eax\n");}
			| lvalue NE_OP_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("cmp eax, [ebx]\n"); printf("setne al\n"); printf("movzx eax, al\n"); printf("mov [ebx], eax\n");}
			| lvalue LESS_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("cmp eax, [ebx]\n"); printf("setl al\n"); printf("movzx eax, al\n"); printf("mov [ebx], eax\n");}
			| lvalue GREAT_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("cmp eax, [ebx]\n"); printf("setg al\n"); printf("movzx eax, al\n"); printf("mov [ebx], eax\n");}
			| lvalue AND_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("and eax, [ebx]\n"); printf("mov [ebx], eax\n");}
			| lvalue OR_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("or eax, [ebx]\n"); printf("mov [ebx], eax\n");}
			| lvalue SUB_ASSIGN _push_eax rvalue {printf("mov ecx, eax\n"); printf("pop ebx\n"); printf("mov eax, [ebx]\n"); printf("sub eax, ecx\n"); printf("mov [ebx], eax\n");}
			| lvalue ADD_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("add eax, [ebx]\n"); printf("mov [ebx], eax\n");}
			| lvalue MUL_ASSIGN _push_eax rvalue {printf("pop ebx\n"); printf("imul eax, [ebx]\n"); printf("mov [ebx], eax\n");}
			| lvalue DIV_ASSIGN _push_eax rvalue {printf("mov ecx, eax\n"); printf("pop ebx\n"); printf("mov eax, [ebx]\n"); printf("xor edx, edx\n"); printf("idiv eax, ecx\n"); printf("mov [ebx], eax\n");}
			| lvalue MOD_ASSIGN _push_eax rvalue {printf("mov ecx, eax\n"); printf("pop ebx\n"); printf("mov eax, [ebx]\n"); printf("xor edx, edx\n"); printf("idiv eax, ecx\n"); printf("mov eax, edx\n"); printf("mov [ebx], eax\n");}
			;

inc_dec		: INC_OP {$$ = "add";}
		| DEC_OP {$$ = "sub";}
		;

unary_expression	: '-' rvalue %prec UMINUS {printf("neg eax\n");}
			| '!' rvalue {printf("cmp eax 0\n"); printf("sete al\n"); printf("movzx eax al");}
			;

_push_eax	: {printf("push eax\n");}
		;

binary_expression	: rvalue '|' _push_eax rvalue {printf("pop ebx\n"); printf("or eax, ebx\n");}
			| rvalue '&' _push_eax rvalue {printf("pop ebx\n"); printf("and eax, ebx\n");}
			| rvalue EQ_OP _push_eax rvalue {printf("pop ebx\n"); printf("cmp ebx, eax\n"); printf("sete al\n"); printf("movzx eax, al\n");}
			| rvalue NE_OP _push_eax rvalue {printf("pop ebx\n"); printf("cmp ebx, eax\n"); printf("setne al\n"); printf("movzx eax, al\n");}
			| rvalue '<' _push_eax rvalue {printf("pop ebx\n"); printf("cmp ebx, eax\n"); printf("setl al\n"); printf("movzx eax, al\n");}
			| rvalue LE_OP _push_eax rvalue {printf("pop ebx\n"); printf("cmp ebx ,eax\n"); printf("setle al\n"); printf("movzx eax, al\n");}
			| rvalue '>' _push_eax rvalue {printf("pop ebx\n"); printf("cmp ebx, eax\n"); printf("setg al\n"); printf("movzx eax, al\n");}
			| rvalue GE_OP _push_eax rvalue {printf("pop ebx\n"); printf("cmp ebx, eax\n"); printf("setge al\n"); printf("movzx eax, al\n");}
			| rvalue LEFT_OP _push_eax rvalue {printf("mov ecx, eax\n");printf("pop eax\n"); printf("shl eax, cl\n");}
			| rvalue RIGHT_OP _push_eax rvalue {printf("mov ecx, eax\n");printf("pop eax\n"); printf("shr eax, cl\n");}
			| rvalue '+' _push_eax rvalue {printf("mov ebx, eax\n");printf("pop eax\n"); printf("add eax, ebx\n");}
			| rvalue '-' _push_eax rvalue {printf("mov ebx, eax\n");printf("pop eax\n"); printf("sub eax, ebx\n");}
			| rvalue '*' _push_eax rvalue {printf("mov ebx, eax\n");printf("pop eax\n"); printf("imul eax, ebx\n");}
			| rvalue '%' _push_eax rvalue {printf("mov ebx, eax\n"); printf("pop eax\n"); printf("xor edx, edx\n"); printf("idiv eax, ebx\n"); printf("mov eax, edx\n");}
			| rvalue '/' _push_eax rvalue {printf("mov ebx, eax\n"); printf("pop eax\n"); printf("xor edx, edx\n"); printf("idiv eax, ebx\n");}
			;

lvalue		: NAME {
			var_type tmp;
			if (local.contains($1))
				tmp = local[$1];
			else if (global.contains($1))
				tmp = std::monostate();
			else
			{
				yyerror("unknown variable");
				YYERROR;
			}
			if (std::holds_alternative<std::monostate>(tmp))
				printf("lea eax, %s\n", $1.c_str());
			else if (std::holds_alternative<std::string>(tmp))
				printf("lea eax, %s\n", std::get<std::string>(tmp).c_str());
			else
				printf("lea eax, [ebp - %d]\n", (std::get<int>(tmp) + 1) * 4);
			}
		| '*' rvalue {}
		| rvalue '[' _push_eax rvalue ']' {printf("pop ecx\n"); printf("lea eax, [ecx+(eax*4)]\n");} {}
		;

%%

#include <stdio.h>
#include <regex>

std::map <std::string, var_type>	local;
std::set <std::string>	global;
int				current_stack_size = 0;
int				current_label = 0;
std::string			switch_end;

extern char yytext[];

int yyerror(char *s)
{
//	return Diagnostic::Error(s, Diagnostic::Error::ERROR).print();
	return fprintf(stderr, "%s\n", s);
}

int yyerror(const std::string &s)
{
	return yyerror(s.c_str());
}

std::string constant_to_string(const constant_type &c)
{
	if (holds_alternative<std::string>(c))
		return get<std::string>(c);
	else
		return std::to_string(get<uintmax_t>(c));
}
