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
    ghdl -a $file
done

echo "Simulating for ${time}..."
ghdl --elab-run ${model_name} --vcd=${model_name}.vcd --stop-time=${time}

if [ $# -gt 2 ]
then
    if [ $3 = "r" ]
    then
	gtkwave ${model_name}.vcd &
    fi
fi
