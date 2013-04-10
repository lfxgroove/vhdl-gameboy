#!/bin/bash

function simulate {
    model_name=$1
    time=$2
    echo "Simulating for ${time}..."
    #Same for this, do _NOT_ move that little ieee part...
    ghdl --elab-run --ieee=synopsys ${model_name} --vcd=${model_name}.vcd --stop-time=${time}
}

function show_help {
    echo "Parameters: Model_Test 100us [r]"
    echo "Workflow: First time, run with r to start gtkwave, then run without r and hit Ctrl+Shift+R to reload"
    exit
}

if [ $# -lt 2 ]; then
    show_help
fi

model_name=$1
time=$2

for file in *.vhd
do
    echo "Compiling $file"
    #DO _NOT_ MOVE --ieee=synopsys to the end of the line as one would expect should work..
    ghdl -a --ieee=synopsys ${file}
done

if [ $# -gt 2 ]
then
    case $3 in
	r | run)
	    echo "Simulating and showing results in gtkwave"
	    simulate $model_name $time
	    gtkwave ${model_name}.vcd &
	    ;;
	s | sim)
	    echo "Simulating"
	    simulate $model_name $time
	    ;;
	t | testa)
	    echo "Compiling and running tests"
	    for dir in tests/*; do
		if [ ${dir} != "tests/bin" ]; then
		    test_name=`echo ${dir} | sed 's/\(\|_\)test\(s\|\)\(\|_\)//g' | sed 's/\///g'`
		    echo "Compiling test: ${test_name}"
		    ghdl -a --ieee=synopsys ${dir}/${test_name}_test.vhd
		    echo "Simulating test: ${test_name^}"
		    #Error suppression is used, perhaps this should be removed?
		    ghdl --elab-run --ieee=synopsys ${test_name^}_Test --vcd=${test_name^}_Test.vcd --stop-time=${time}
                    # > /dev/null 2>&1
		    #Todo: Diff the files in some way!
		fi
	    done
	    ;;
	*)
	    show_help
	    ;;
    esac
fi
