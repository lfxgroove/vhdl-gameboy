#!/bin/bash

if [ $# -eq 0 ]
then
    echo "Usage: [clean|bitgen|sim|prog]"
    echo "See build-data/Makefile for details"
    exit 0
fi

mkdir build
cp lab.ucf build/
cp *.vhd build/
cp -r build-data/* build/

cd build
make $1

