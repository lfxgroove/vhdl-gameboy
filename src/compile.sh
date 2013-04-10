#!/bin/bash

if [ $# -lt 2 ]
then
    echo "Parameters: Model_Test 100us [r]"
    echo "Workflow: First time, run with r to start gtkwave, then run without r and hit Ctrl+Shift+R to reload"
    exit
fi

model_name=$1
time=$2

for file in *.vhd
do
    echo "Compiling $file"
    #DO _NOT_ MOVE --ieee=synopsys to the end of the line as one would expect should work..
    ghdl -a --ieee=synopsys ${file}
done

echo "Simulating for ${time}..."
#Same for this, do _NOT_ move that little ieee part...
ghdl --elab-run --ieee=synopsys ${model_name} --vcd=${model_name}.vcd --stop-time=${time}

if [ $# -gt 2 ]
then
    if [ $3 = "r" ]
    then
	gtkwave ${model_name}.vcd &
    fi
fi
