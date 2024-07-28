#!/bin/sh
set -e
for i in $(seq 1 $#)
do
  eval S$i=$(mktemp)
  eval O$i=$(mktemp)
  if echo "$(eval echo \$$i)" | grep -q '\.b$'
  then
    ./B <"$(eval echo \$$i)" >$(eval echo \$S$i)
    gcc -c -m32 -x assembler "$(eval echo \$S$i)" -o $(eval echo \$O$i)
  elif echo "$(eval echo \$$i)" | grep -q '\.c$'
  then
    gcc -c -m32 -x c "$(eval echo \$$i)" -o $(eval echo \$O$i)
  elif echo "$(eval echo \$$i)" | grep -q '^-l'
  then
    LD_FLAGS="${LD_FLAGS} $(eval echo \$$i)"
  elif echo "$(eval echo \$$i)" | grep -q '\.s$'
  then
    gcc -c -m32 -x assembler "$(eval echo \$$i)" -o $(eval echo \$O$i)
  else
    echo 'file extension not recognised'
    exit 1
  fi
  rm "$(eval echo \$S$i)"
done
ld -m elf_i386 -dynamic-linker /lib/ld-linux.so.2 $LD_FLAGS $(eval echo $(seq -f '$O%.0f' -s ' ' 1 $#)) brt0.o
rm $(eval echo $(seq -f '$O%.0f' -s ' ' 1 $#))
