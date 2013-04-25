#!/bin/bash

if [ $# -lt 1 ]
then
    echo "Usage: $0 [file_to_compile] [r]"
    echo "Example: $0 fill_memory"
    echo "Note: Assumes the command lcc is the gameboy c-compiler and that visualboyadvance is avaliable for running the rom"
    exit 1
fi

if [ -e $1.gb ]
then
    rm $1.gb
fi

#On Windows, for some reason, we cannot trust the return code
#of lcc. Therefore check for file instead.
lcc -Wa-l -Wl-m -Wl-j -o $1.gb $1.c

if [ -e $1.gb ]
then
    echo "Running"
    if [ $# -gt 1 ]
    then
	visualboyadvance $1.gb
    fi
else
    echo "Compilation failed..."
fi
