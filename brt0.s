.intel_syntax noprefix
.text
.globl syscall
syscall:
.long syscall + 4
enter 0, 0
mov eax, DWORD PTR [ebp+8]
mov ebx, DWORD PTR [ebp+12]
mov ecx, DWORD PTR [ebp+16]
mov edx, DWORD PTR [ebp+20]
mov esi, DWORD PTR [ebp+24]
mov edi, DWORD PTR [ebp+28]
int 0x80
leave
ret
.globl _start
_start:
sub esp, 32
mov ebx, DWORD PTR [esp+32]
lea eax, [esp+40+ebx*4]
push eax
lea eax, DWORD PTR [esp+40]
push eax
push DWORD PTR [esp+40]
lea eax, main
mov eax, [eax]
call eax
mov ebx, eax
mov eax, 1
int 0x80
