#include <iostream>
#include <fstream>
#include <string>
#include <cstring>

#include "parser.hpp"
#include "tokenizer.hpp"

void run_test(const std::string& dir_name, const std::string& test_name)
{
  Tokenizer t(dir_name + "/" + test_name + ".stim");
  Parser p(t, dir_name  + "/");
  std::cout << "Skickade in: " << dir_name + "/" << " som base path" << std::endl;
  // std::cout << "Skickar in: " << dir_name + "/" + test_name + ".stim" << std::endl;
  Tests to_run = p.parse();
  Tests faulty;
  bool all_ok = true;
  int i = 1;
  int num_tests = to_run.size();
  std::cout << "Running " << num_tests << " tests for " << test_name << ": " << std::endl;
  //Todo: run one test only with something like this and command line parameter
  // if (to_run.front().run(test_name))
  //   {
  //     std::cout << "OK" << std::endl;
  //   }
  // else
  //   {
  //     std::cout << "NEIN" << std::endl;
  //     std::cout << to_run.front().diff() << std::endl 
  // 		<< to_run.front() << std::endl;
  //   }
  for (Tests::iterator it = to_run.begin();
       it != to_run.end();
       ++it, ++i) 
    {
      std::cout << "Test " << i << " of " << num_tests << ":" << std::flush;
      if ((*it).run(test_name))
  	{
  	  std::cout << "OK" << std::endl;
  	}
      else
  	{
  	  all_ok = false;
  	  std::cout << "FAIL, here's some info:" << std::endl;
  	  faulty.push_back(*it);
  	  std::cout << it->diff() << std::endl;
  	  std::cout << "Here's the test: " << std::endl;
  	  std::cout << *it << std::endl;
  	  // std::cout << "Test failed! Info: " << std::endl
  	  // 	    << *it << std::endl;
  	}
    }
  // std::cout << std::endl;
  // if (!all_ok)
  //   {
  //     std::cout << "Testing was interrupted by a/some faulty test/s" << std::endl;
  //     std::cout << "Tests that failed: " << std::endl;
  //     //TODO: Show them.
  //   }
}

void print_usage(const char* name)
{
  using std::cout;
  using std::endl;
  
  cout << "Usage: " << name << " options " << endl;
  cout << "-d DIRNAME denotes which dir you would like to " << endl;
  cout << "           run tests for" << endl;
  // cout << "-t         run the feed part of a test, ie, feed " << endl;
  // cout << "           a file to the testbench and capture   " << endl;
  // cout << "           output. " << endl;
  // cout << "-i         run the diff part of the program 
}

std::string find_test_name(std::string& dir_name)
{
  if (dir_name.substr(dir_name.length()-1, dir_name.length()) == "/")
    dir_name = dir_name.substr(0, dir_name.length() - 1);
  
  std::string::size_type found;
  if ((found = dir_name.find_last_of("/")) != std::string::npos)
    {
      return dir_name.substr(found + 1, dir_name.length());
    }
  else
    {
      //this isn't entirely true but lets go with it for now
      std::cout << "Error: Can't continue, dir is malformed" << std::endl;
      return "";
    }
}

int main(int argc, char** argv) 
{
  if (argc < 2)
    {
      print_usage(argv[0]);
      return 0;
    }
  
  std::string dir_name, test_name;
  bool dir_found = false;
  
  for (int i = 1; i < argc; ++i)
    {
      if (strcmp(argv[i], "-d") == 0)
	{
	  dir_name = argv[++i];
	  dir_found = true;
	}
    }
  
  if (!dir_found) 
    {
      std::cout << "Error: You must supply a -d option" << std::endl;
      print_usage(argv[0]);
      return 0;
    }
  
  test_name = find_test_name(dir_name);
  if (test_name == "")
    return 0;
  
  std::cout << "Dir name is: " << dir_name << std::endl;
  std::cout << "Test name is:" << test_name << std::endl;
  
  run_test(dir_name, test_name);

  return 0;
}
