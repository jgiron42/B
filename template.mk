NAME ?= $(shell basename $$(pwd))

SRCS_DIR ?= .

OBJS_DIR ?= obj

INCLUDE_DIR ?= .

SRCS ?= $(wildcard *.c) $(wildcard *.cpp)

OBJS_DIR_TREE := $(sort $(addprefix ${OBJS_DIR}/, $(dir ${SRCS})))

LIB_ARG = $(foreach path, $(LIBS), -L $(dir $(path)) -l $(notdir $(path)))

INCLUDE_ARG = $(addprefix -I ,${INCLUDE_DIR}) $(addprefix -I, $(dir ${LIBS}))

OBJS := $(SRCS:%.c=${OBJS_DIR}/%.o)

IDEPS := $(SRCS:%.c=${OBJS_DIR}/%.d)

CFLAGS ?= -Wall -Werror -Wextra

all: $(NAME)

$(NAME): ${OBJS_DIR} ${OBJS_DIR_TREE} $(OBJS) $(MAKE_DEP)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LIB_ARG)

${OBJS_DIR}:
	mkdir -p $@
	[ -f .gitignore ] && (grep '^'"$@"'$$' .gitignore || echo "$@" >> .gitignore) || true

${OBJS_DIR_TREE}:
	mkdir -p $@

${OBJS_DIR}/%.o: ${SRCS_DIR}/%.c
	$(CC) $(CFLAGS) ${INCLUDE_ARG} -MMD -c $< -o $@

${SRCS_DIR}/%.yy.c: ${SRCS_DIR}/%.l
	cd  $(SRCS_DIR) && $(LEX) ${*}.l && mv lex.yy.c ${*}.yy.c

${SRCS_DIR}/%.tab.c ${SRCS_DIR}/%.tab.h ${SRCS_DIR}/%.def.h: ${SRCS_DIR}/%.y
	cd  $(SRCS_DIR) && $(YACC) -dtv -b $* ${*}.y

$(MAKE_DEP):
	make -C $(dir $@) $(notdir $@)

clean:
	rm -rf $(OBJS_DIR)

fclean: clean
	rm -f $(NAME)

re: fclean all

.PHONY: clean all fclean re

.PRECIOUS: ${OBJS_DIR}/%.d

-include ${IDEPS}