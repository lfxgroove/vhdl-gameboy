Quick guide on how out tests work.

_______1.Background_______
At the start of the project we realised testing everything would be a pain if we would have to do it manually. So we decided to create a simple way to do automated tests.


_______2.How to run the finished test_______
Go to the projects /src directory and type the below to your terminal.
./compile.sh test_directory_name flags (test to run, -1 for all tests in file) and the time that each test can take.
Examples:
./compile.sh jump_op t 21 2000 # will run test 21 in jump_op_tests for 2000 (units of time)
./compile.sh jump_op t -1 # will run test 21 in jump_op_tests for 2000 (units of time)

Works for [insert OS 32/64bits] systems.


_______3.The "languge"_______
Inspired by JUnit we created the following syntax:
@test , @prepare, @check are all that exist in our "language".

Below is a documented example on how things work.

#This is how you do comments.
@prepare {
   35 03 # this is code that you want to run before each test.

   [0200] 76 # Puts OP-code 76 at adress 0200.
   [0220] 35 04 # you can do several of these
   ...
   ## dont put any code here!
}

# Test 77 - we have decided to always write which OP-code we are going to test.
# Test number X: - same as above, write which test in line this is.
@test {
  77 # code that is to be run

@check {
  [C000] OB # an assert. if 0xC000 does not contain 0x0B then the test fails
  [C100] 00 #
  ...
  }
}

_______4.To be added later on (hopfully)_______

How to generate the implemented_op_codes.txt file.
Add more details to heading 2
There was something more that I forgott..


_______5.Final thoughts and notes_______

Note that, all values are assumed to be in Hex, so 0B is 0x0B and so on. 

When writing tests or asseembler in general you can use the list in implemented_op_codes.txt to help you find
all OP-codes that are implemented and tested. The list is as of this moment listed with the tested OP-codes first
in numerical order and then all (8) OP-codes that are not tested after that, also in numerical order.

Remember if you write more tests describe WHY you did the test. It is important to explain
what the test does as well but more important is for people to understand why it is there
and what it is tests. But this I think you already know ^^

The testing framework and the tests themselves are written by guys (us) without much experience
in the field. Any improvments or suggestions of such are very much welcome!



