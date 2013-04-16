#trying to learn something about makefiles :)

CC=g++
CFLAGS=-c -g -Wall -std=c++0x
LDFLAGS=-g
PROG_NAME=tester

all: main

clean:
	rm -f *.o $(PROG_NAME)

main: main.o tokenizer.o parser.o test.o addrdata.o testfile.o util.o diff.o
	$(CC) $(LDFLAGS) main.o tokenizer.o parser.o test.o addrdata.o testfile.o  util.o \
	diff.o -o $(PROG_NAME)

addrdata.o: addrdata.cpp 
	$(CC) $(CFLAGS) addrdata.cpp

tokenizer.o: tokenizer.cpp
	$(CC) $(CFLAGS) tokenizer.cpp 

main.o: main.cpp
	$(CC) $(CFLAGS) main.cpp

parser.o: parser.cpp
	$(CC) $(CFLAGS) parser.cpp

test.o: test.cpp
	$(CC) $(CFLAGS) test.cpp

testfile.o: testfile.cpp
	$(CC) $(CFLAGS) testfile.cpp

util.o: util.cpp
	$(CC) $(CFLAGS) util.cpp

diff.o: diff.cpp
	$(CC) $(CFLAGS) diff.cpp