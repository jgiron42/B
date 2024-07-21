NAME = B

RUNTIME = brt0.o

SRCS =	parser.tab.c \
		scanner.yy.c \
		main.c

SRCS_DIR = src

DEPENDENCIES = ${SRCS_DIR}/parser.tab.h

OBJS_DIR = .obj

INCLUDE_DIR = srcs

CFLAGS = -g3 -D YYDEBUG

LDFLAGS =

all: ${RUNTIME}
fclean: clean_runtime

clean_runtime:
	rm -f ${RUNTIME}

${RUNTIME}: ${RUNTIME:%.o=%.s}
	$(CC) -c -m32 $< -o $@

include template.mk
