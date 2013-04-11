#include <iostream>
#include <fstream>
#include <string>
#include <cstring>

#include "parser.hpp"
#include "tokenizer.hpp"

void run_test(const std::string& dir_name, const std::string& test_name)
{
  Tokenizer t(dir_name + "/" + test_name + ".stim");
  Parser p(t);
  Tests to_run = p.parse();
}

void print_usage(const char* name)
{
  using std::cout;
  using std::endl;
  
  cout << "Usage: " << name << " options " << endl;
  cout << "-d DIRNAME denotes which dir you would like to " << endl;
  cout << "           run tests for" << endl;
}

std::string find_test_name(const std::string& dir_name)
{
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
