

%{
#define _GNU_SOURCE
#include <search.h>
#include <assert.h>
#include <stdbool.h>
#include <string.h>
#include <malloc.h>
#include <stdio.h>
int yyerror(char *s);
#include <stdint.h>
typedef struct {
	char *name;
	enum {EXTERN, STACK, INTERNAL} type;
	int value;
} var_type;
int yylex(void);
var_type **insert_var(void **ns, char *name, var_type var);
void put_internals();
void destroy_namespace(void *ns);
extern void * global;
extern void * local;
extern int	current_stack_size;
extern int	current_label;
extern int	current_switch_label;
extern char	*current_function;
int	compare(const void *, const void*);
%}

%right ELSE
%nonassoc IF

%token AUTO EXTRN SWITCH CASE WHILE GOTO RETURN

%union {
	int integer;
	struct {int first; int second;} int_pair;
	char *string;
}

%token <string> NAME
%token <string> STRING_LITERAL
%token <string> CONSTANT
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

%type <integer> rvalue_list _label while_condition while_begin switch_statement
%type <integer_pair> ternary
%type <string> sym_name vec_name inc_dec
%type <scope> fun_definition

%%

wrapper : {
		puts(".intel_syntax noprefix");
		puts(".text");
		global = NULL;
} program {
destroy_namespace(global);
}
;

program	: definition
	| program definition
	;

definition : var_definition
	| vec_definition
	| fun_definition
	;

var_definition	: sym_name ';' {  printf(".long 0\n"); printf(".text\n"); }
		| sym_name CONSTANT ';' { printf(".long %s\n", $2); printf(".text\n"); free($2);}
		| sym_name NAME ';' { printf(".long %s\n", $2); printf(".text\n"); free($2);}
		;

sym_name	: NAME {printf(".section .data\n"); printf("%s:\n", $1);$$ = $1; insert_var(&global, $1, (var_type){.type = EXTERN});free($1);}
		;

vec_name	: sym_name { printf(".long %s + 4\n", $1); $$ = $1;}
		;

vec_definition	: vec_name '[' ']' ';' { printf(".text\n"); }
		| vec_name '[' CONSTANT ']' ';' { printf(".space %s, 0\n", $3); printf(".text\n"); free($3);}
		| vec_name '[' ']' ival_list ';' { printf(".text\n"); }
      		| vec_name '[' CONSTANT ']' ival_list ';' { printf(".if (.-%s) < %s\n", $1, $3); printf(".space %s-(.-%s) , 0\n", $3, $1); printf(".endif\n"); printf(".text\n"); free($3);}
		;

ival_list	: ival
		| ival_list ',' ival
		;

ival		: CONSTANT {printf(".long %s\n", $1);free($1);}
		| NAME {printf(".long %s\n", $1);free($1);}
		;

fun_definition_name	: NAME {
				printf(".text\n.globl %s\n%s:\n", $1, $1);
				printf(".long %s + 4\n", $1);
				printf("enter 0, 0\n");
				insert_var(&global, $1, (var_type){.type = EXTERN});
				current_stack_size = 0;
				current_function = $1;
                }
			;

fun_definition	: fun_definition_name  '('  {
			local = NULL;
		} optional_parameter_list ')' {current_stack_size = 0;}  statement {
			printf("leave\nret\n");
			put_internals();
			destroy_namespace(local);
			free(current_function);
			current_function = NULL;
		}
		;

parameter : NAME {insert_var(&(local), $1, (var_type){.type = STACK, .value = current_stack_size-- - 3});free($1);}
		  ;

parameter_list	: parameter
		| parameter_list ',' parameter
		;

optional_parameter_list : parameter_list
						|
						;

statement	: AUTO auto_var_list ';' statement
		| EXTRN extrn_var_list ';' statement
		| NAME ':' {
				int lbl;
				var_type compare_node = (var_type){.name = $1};
				var_type **ptr;
				if (ptr = tfind(&compare_node, &local, &compare)) {
					(*ptr)->value = 1;
				} else {
					insert_var(&local, $1, (var_type){.type = INTERNAL, .value = 1});
				}
				printf("jmp [.L.%s.%s]\n", current_function, $1);
				printf(".L.%s.%s:\n", current_function, $1);
				printf(".long .L.%s.%s + 4\n", current_function, $1);
				free($1);
			} statement
		| case_statement
//		| '{' {$<integer>$ = current_stack_size;} statement_list '}' {printf("add esp, %d\n", (current_stack_size - $<integer>2) * 4); current_stack_size = $<integer>2;}
		| '{' statement_list '}'
		| if_statement
		| while_statement
		| switch_statement
		| GOTO rvalue ';' {printf("jmp eax\n");}
		| RETURN ';' {printf("leave\nret\n");}
		| RETURN '(' rvalue ')' ';' {printf("leave\nret\n");}
		| ';'
		| rvalue ';'
		;

switch_statement: SWITCH _label rvalue {
        	$<integer>$ = current_switch_label;
        	current_switch_label = $2;
        	printf("jmp .L%d\n", current_switch_label);
        } statement
		{
			printf(".L%d:\n", current_switch_label);
			current_switch_label = $<integer>4;
		}
				;

case_statement: CASE CONSTANT ':' _label _label
		{
			printf("jmp .L%d\n", $4);
			printf(".L%d:\n", current_switch_label);
			printf("cmp eax, %s\n", $2);
			printf("jne .L%d\n", $5);
			current_switch_label = $5;
			printf(".L%d:\n\n", $4);
			free($2);
		} statement
		;



_label		: {$$ = current_label++;}
		;

_if_goto	: {
			printf("cmp eax, 0\n");
			printf("je .L%d\n", $<integer>0);
		}
		;

if_statement	: IF '(' rvalue ')' _label _if_goto statement {printf(".L%d:\n", $5);}
		| IF '(' rvalue ')' _label _if_goto statement ELSE _label {printf("jmp .L%d\n", $9); printf(".L%d:\n", $5);} statement {printf(".L%d:\n", $9);}
		;

while_condition: _label {printf(".L%d:\n", $1); $$ = $1;}
		;

while_begin		: _label {
				printf("cmp eax, 0\n");
				printf("je .L%d\n", $1);
                         }
                ;

while_statement	: WHILE while_condition '(' rvalue ')' while_begin statement
                                             {printf("jmp .L%d\n", $2);printf(".L%d:\n", $6);}
		;

statement_list	: statement
		| statement_list statement
		;

auto_var_list	: name_init
		| auto_var_list ',' name_init
		;

name_init	: NAME {
				insert_var(&(local), $1, (var_type){.type = STACK, .value = current_stack_size++});
				printf("push  0\n");
				free($1);
			}
		| NAME CONSTANT {
			int vec_size = atoi($2);
			insert_var(&(local), $1, (var_type){.type = STACK, .value = current_stack_size += 1 + vec_size});
			printf("mov eax, esp\n");
			printf("inc eax\n");
			printf("push eax\n");
			printf("sub esp, %d\n", vec_size);
			free($1);
			free($2);
		}
		;

extrn_var_list	: NAME {insert_var(&(local), $1, (var_type){.type = EXTERN}); free($1);}
		| extrn_var_list ',' NAME {insert_var(&(local), $3, (var_type){.type = EXTERN}); free($3);}
		;

rvalue		: '(' rvalue ')'
		| lvalue {printf("mov eax, [eax]\n");}
		| CONSTANT {printf("mov eax, %s\n", $1);free($1);}
		| assignment_expression
		| inc_dec lvalue %prec PRE_INC_DEC
		{
			printf("mov ebx, [eax]\n");
			printf("%s ebx, 1\n", $1);
			printf("mov [eax], ebx\n");
			printf("mov eax, ebx\n");
		}
		| lvalue inc_dec %prec POST_INC_DEC
		{
			printf("mov ebx, [eax]\n");
			printf("mov ecx, ebx\n");
			printf("%s ebx, 1\n", $2);
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
			| '!' rvalue {printf("cmp eax, 0\n"); printf("sete al\n"); printf("movzx eax, al\n");}
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
				var_type **tmp;
				var_type comp_node = (var_type){.name = $1};
				(tmp = (var_type **)tfind(&comp_node, &local, &compare)) ||
				(tmp = (var_type **)tfind(&comp_node, &global, &compare)) ||
				(tmp = insert_var(&local, $1, (var_type){.type = INTERNAL, .value = 0}));
				assert(tmp);
				switch ((*tmp)->type) {
					case EXTERN:
					printf("lea eax, %s\n", $1);
					break;
					case STACK:
					printf("lea eax, [ebp - %d]\n", ((*tmp)->value + 1) * 4);
					break;
					case INTERNAL:
					printf("lea eax, .L.%s.%s\n", current_function, (*tmp)->name);
					break;
				}
				free($1);
			}
		| '*' rvalue {}
		| rvalue '[' _push_eax rvalue ']' {printf("pop ecx\n"); printf("lea eax, [ecx+(eax*4)]\n");} {}
		;

%%

#include <stdio.h>

void * global;
void * local;

int				current_stack_size = 0;
int				current_label = 0;
int				current_switch_label = -1;
char			*current_function = NULL;

extern char yytext[];

int yyerror(char *s)
{
	return fprintf(stderr, "%s\n", s);
}

var_type **insert_var(void **ns, char *name, var_type var) {
	var_type *node = malloc(sizeof(var_type));
	*node = var;
	node->name = strdup(name);
	if (tfind(node, ns, &compare)) {
		// error
	}
	return tsearch(node, ns, &compare);
}

int	compare(const void *l, const void *r) {
	return strcmp(((var_type*)l)->name, ((var_type*)r)->name);
}

void visit_variable(const void *nodep, VISIT which, int depth) {
	if ((which == preorder || which == leaf) && (*(var_type **)nodep)->type == INTERNAL && (*(var_type **)nodep)->value == 0) {
		printf(".section .data\n");
		printf(".L.%s.%s:\n", current_function, (*(var_type **)nodep)->name);
		printf(".long 0\n");
		printf(".text\n");
	}
}

void put_internals() {
	twalk(local, &visit_variable);
}

void destroy_variable(void *nodep) {
	free(((var_type *)nodep)->name);
	free(nodep);
}

void destroy_namespace(void *ns) {
	tdestroy(ns, &destroy_variable);
}
