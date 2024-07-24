# B
B is a B compiler for i386 written in C using lex and yacc.
this repo include the compiler and a minimalist runtime for linux (contains an entrypoint and a syscall function)

To run this project, use make to compile the compiler and the runtime then use the compile.sh script to compile on or more B files to executable

The main goal of this project was to code-golf a compiler.
The compiler doesn't have any AST and works only by syntax directed translation. 
It read B code from stdin and output asm i386 code to stdout.
Using only syntax directed translation required a few hacks (eg in switch statements or in function calls) but this allowed to output asm code for each line of input immediately.

The compiler follow mostly the original spec from Thompson with few exceptions to make it work on i386.
