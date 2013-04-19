#!/bin/bash

if [ $# -lt 1 ]
then
    echo "Specify the rom file to be tested (no extension)."
    echo "Usage: [rom file] [r]"
    echo "R is optional and starts gtkwave."
    exit 0
fi

FILE=roms/$1.gb

if [ ! -f $FILE ]
then
    echo "No such file: $FILE"
    exit 0
fi

echo "Preparing rom..."
./roms/dump.pl $FILE > ./roms/rom.txt

model_name=Rom_Test

./compile.sh

echo "Running..."
ghdl --elab-run --ieee=synopsys ${model_name} --vcd=${model_name}.vcd --stop-time=20ms 2> ./roms/errors.txt
if [ $? -ne 0 ]
then
    echo "Errors (last 6 lines from ./roms/errors.txt):"
    tail -n 6 ./roms/errors.txt
fi

if [ $# -gt 1 ]
then
    if [ $2 = r ]
    then
	gtkwave ${model_name}.vcd &
    fi
fi

echo "Done!"
