#!/bin/bash

if [ $# -lt 1 ]
then
    echo "Specify the rom file to be tested (no extension)."
    echo "Usage: [rom file] [simulation mode]"
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

echo "Running..."
./compile.sh Rom_Test 40us $2

echo "Done!"
