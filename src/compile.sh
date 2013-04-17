#!/bin/bash

function simulate {
    model_name=$1
    time=$2
    echo "Simulating for ${time}..."
    #Same for this, do _NOT_ move that little ieee part...
    #TODO: Add ability to use --disp-time as a flag
    ghdl --elab-run --ieee=synopsys ${model_name} --vcd=${model_name}.vcd --stop-time=${time}
}

function show_help {
    echo "Parameters: Model_Test 100us [r]"
    echo "Workflow: First time, run with r to start gtkwave, then run without r and hit Ctrl+Shift+R to reload"
    exit
}

model_name=$1
time=$2

for file in *.vhd
do
    echo "Compiling $file"
    #DO _NOT_ MOVE --ieee=synopsys to the end of the line as one would expect should work..
    ghdl -a --ieee=synopsys ${file} || exit
done

if [ $# -eq 1 ]; then
    if [ $1 = "t" ]; then
	#Test everything
	for dir in tests/*; do
	    if [ ${dir} != "tests/bin" -a ${dir} != "tests/sample_test" ]; then
		test_name=`echo ${dir} | sed 's/\(\|_\)test\(s\|\)\(\|_\)//g' | sed 's/\///g'`
		echo "Compiling test: ${test_name}"
		ghdl -a --ieee=synopsys ${dir}/${test_name}_test.vhd || exit
		echo "Simulating test: ${test_name^}"
	        #Error suppression is used, perhaps this should be removed?
                #ghdl --elab-run --ieee=synopsys ${test_name^}_Test --vcd=${test_name^}_Test.vcd --stop-time=${time}
                # > /dev/null 2>&1
		if [ ! -d ${dir}/stimulus ]
		then
		    echo Creating ${dir}/stimulus
		    mkdir ${dir}/stimulus
		fi
		if [ ! -d ${dir}/results ]
		then
		    echo Creating ${dir}/results
		    mkdir ${dir}/results
		fi

		tester/tester -d ${dir}
	    fi
	done

    fi
    exit;
fi

if [ $# -eq 2 ]; then
    if [ $2 = "t" ]; then
        #Run individual test file
	test_name=${model_name}
	test_path=${model_name}_test
	echo "Compiling and running test ${test_name}"
	if [ -e "tests/${test_path}" ]; then
	    ./tester/tester -d ./tests/${test_path}/
	else
	    echo "The test: ${test_name} doesn't exist"
	    exit
	fi
    else
	show_help
    fi
fi

if [ $# -gt 2 ]; then
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
	    show_help
	    ;;
	*)
	    show_help
	    ;;
    esac
fi
