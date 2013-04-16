#!/bin/bash

function print_usage {
    echo "Usage:"
    echo "$0 name_of_test"
    echo "   name_of_test is the test name, ie: alu"
    echo "     _test will be added to the end, no need to add that"
    exit
}

if [ $# -lt 1 ]; then
    print_usage
fi

mkdir tests/${1}_test
cp tests/sample_test/sample_test.vhd tests/${1}_test/${1}_test.vhd
sed -i "s/HOWDAREYOUCALLMEFAT/${1}_Test/g" tests/${1}_test/${1}_test.vhd
sed -i "s/YOUWONTGETTHEHORSE/${1}_test/g" tests/${1}_test/${1}_test.vhd
mkdir tests/${1}_test/{results,stimulus}
touch tests/${1}_test/${1}_test.stim
echo "#This is where your code goes, dont forget:" >> tests/${1}_test/${1}_test.stim
echo "#@prepare, @test { @check } for it to work:" >> tests/${1}_test/${1}_test.stim
