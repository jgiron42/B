NAME ?= $(shell basename $$(pwd))

SRCS_DIR ?= .

OBJS_DIR ?= obj

INCLUDE_DIR ?= .

SRCS ?= $(wildcard *.cpp)


OBJS_DIR_TREE := $(sort $(addprefix ${OBJS_DIR}/, $(dir ${SRCS})))

LIB_ARG = $(foreach path, $(LIBS), -L $(dir $(path)) -l $(notdir $(path)))

INCLUDE_ARG = $(addprefix -I ,${INCLUDE_DIR}) $(addprefix -I, $(dir ${LIBS}))

OBJS := $(SRCS:%.cpp=${OBJS_DIR}/%.o)

IDEPS := $(SRCS:%.cpp=${OBJS_DIR}/%.d)

LEX	?= flex

CXXFLAGS ?= -Wall -Werror -Wextra

all: $(NAME)

$(NAME): ${OBJS_DIR} ${OBJS_DIR_TREE} ${DEPENDENCIES} $(OBJS) $(MAKE_DEP)
		$(CXX) $(CXXFLAGS) -o $@ $(OBJS) $(LIB_ARG) $(LDFLAGS)

${SRCS}: $(addprefix ${SRCS_DIR}/, ${SRCS})

${OBJS_DIR}:
	mkdir -p $@
	[ -f .gitignore ] && (grep '^'"$@"'$$' .gitignore || echo "$@" >> .gitignore) || true

${OBJS_DIR_TREE}:
	mkdir -p $@

${OBJS_DIR}/%.o: ${SRCS_DIR}/%.cpp
	$(CXX) $(CXXFLAGS) ${INCLUDE_ARG} -MMD -c $< -o $@

${SRCS_DIR}/%.yy.cpp ${SRCS_DIR}/%.yy.hpp: ${SRCS_DIR}/%.l
	$(LEX) -r $(SRCS_DIR) -b $* $< && mv ${SRCS_DIR}/${*}.yy.c ${SRCS_DIR}/${*}.yy.cpp

${SRCS_DIR}/%.tab.cpp ${SRCS_DIR}/%.tab.hpp ${SRCS_DIR}/%.def.hpp: ${SRCS_DIR}/%.y
	$(YACC) -dtv  -+ -r $(SRCS_DIR) -b $* $<

$(MAKE_DEP):
	make -C $(dir $@) $(notdir $@)

clean:
	rm -rf $(OBJS_DIR) ${DEPENDENCIES}

fclean: clean
	rm -f $(NAME)

re: fclean all

.PHONY: clean all fclean re

.PRECIOUS: ${OBJS_DIR}/%.d

-include ${IDEPS}
