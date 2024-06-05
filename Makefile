NAME = B

SRCS =	parser.tab.cpp \
		scanner.yy.cpp \
		main.cpp

SRCS_DIR = src

DEPENDENCIES = ${SRCS_DIR}/scanner.yy.hpp ${SRCS_DIR}/parser.def.hpp

OBJS_DIR = .obj

INCLUDE_DIR = srcs

CXXFLAGS = -g3 -std=c++20 -D YYDEBUG

LDFLAGS =

LEX = ../ft_lex/ft_lex
YACC = ../ft_yacc/ft_yacc

include template_cpp.mk
