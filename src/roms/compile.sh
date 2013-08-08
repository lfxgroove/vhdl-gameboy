# Copyright (c) 2013, Filip Strömbäck, Anton Sundblad, Alex Telon
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * The names of the contributors may not be used to endorse or promote products
#       derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL FILIP STRÖMBÄCK, ANTON SUNDBLAD OR ALEX TELON 
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#!/bin/bash

if [ $# -lt 1 ]
then
    echo "Usage: $0 [file_to_compile] [r/port]"
    echo "Example: $0 fill_memory"
    echo "Note: Assumes the command lcc is the gameboy c-compiler and that visualboyadvance is avaliable for running the rom"
    echo "If port is specified, the rom will be uploaded to the specified port using ../serial/serial"
    exit 1
fi

if [ $# -gt 1 ]
then
    if [ $2 = a ]
    then
	lcc -Wa-l -Wl-m -Wl-j -S -o $1.asm $1.c
	exit 0
    fi
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
	if [ $2 = r ]
	then
	    visualboyadvance $1.gb
	else
	    ../serial/serial $2 $1.gb
	fi
    fi
else
    echo "Compilation failed..."
fi
