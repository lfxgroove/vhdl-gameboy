#include <iostream>
#include <fstream>
#include <string>
#include <cstring>

#include "parser.hpp"
#include "tokenizer.hpp"

void run_test(const std::string& dir_name, const std::string& test_name, int test_num, bool one_test_only, int simulation_time)
{
  Tokenizer t(dir_name + "/" + test_name + ".stim");
  Parser p(t, dir_name  + "/");
  Tests to_run = p.parse();
  Tests faulty;
  bool all_ok = true;
  int i = 1;
  int num_tests = to_run.size();
  //TODO: Fix this kludge..
  if (test_num != -1)
    {
      std::cout << "Running test " << test_num << " of " 
		<< num_tests << " for " << test_name << ": " << std::endl;
      for (Tests::iterator it = to_run.begin();
	   it != to_run.end();
	   ++it, ++i) 
	{
	  if (i == test_num) 
	    {
	      if ((*it).run(test_name, simulation_time))
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
		}
	    }
	  else
	    if (i > test_num && one_test_only)
	      break;
	}
    }
  else
    {
      std::cout << "Running " << num_tests << " tests for " << test_name << ": " << std::endl;
      for (Tests::iterator it = to_run.begin();
	   it != to_run.end();
	   ++it, ++i) 
	{
	  std::cout << "Test " << i << " of " << num_tests << ":" << std::flush;
	  if ((*it).run(test_name, simulation_time))
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
	    }
	}
    }
}

void print_usage(const char* name)
{
  using std::cout;
  using std::endl;
  
  cout << "Usage: " << name << " options " << endl;
  cout << "-d DIRNAME denotes which dir you would like to " << endl;
  cout << "           run tests for" << endl;
  cout << "-n NUMBER  runs a certain test for the given DIRNAME" << endl;
  cout << "           ie: tester -n 10 -d tests/derp_test/ would" << endl;
  cout << "           run the tenth test in tests/derp_test/derp_test.stim" << endl;
  cout << "-o         Run only one test, use in conjunction with -n" << endl;
  cout << "-t NUMBER  Simulate each test for NUMBER microseconds, default is 1600" << endl;
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
  int test_num = -1, simulation_us = 1600; //1600 us is default
  bool dir_found = false, num_found = false, only_one_found = false, sim_time_found = false;
  
  for (int i = 1; i < argc; ++i)
    {
      if (strcmp(argv[i], "-d") == 0)
	{
	  dir_name = argv[++i];
	  dir_found = true;
	}
      else if (strcmp(argv[i], "-n") == 0)
	{
	  std::stringstream ss;
	  ss << argv[++i];
	  ss >> test_num;
	  if (test_num > 0)
	    num_found = true;
	}
      else if (strcmp(argv[i], "-o") == 0)
	{
	  only_one_found = true;
	}
      else if (strcmp(argv[i], "-t") == 0)
	{
	  std::stringstream ss;
	  ss << argv[++i];
	  ss >> simulation_us;
	  if (simulation_us > 0)
	    sim_time_found = true;
	  else
	    simulation_us = 1600; //Kludge..
	}
    }
  
  if (!dir_found) 
    {
      std::cout << "Error: You must supply a -d option" << std::endl;
      print_usage(argv[0]);
      return 0;
    }
  
  if (num_found && !dir_found)
    {
      std::cout << "Error: You must supply the -d option if using -n" << std::endl;
      print_usage(argv[0]);
      return 0;
    }
  
  //Add a check that we are in the src dir and nothing else!
  
  test_name = find_test_name(dir_name);
  if (test_name == "")
    return 0;
  
  std::cout << "Running with simulation time of: " << simulation_us << std::endl;
  std::cout << "Dir name is: " << dir_name << std::endl;
  std::cout << "Test name is:" << test_name << std::endl;
  
  run_test(dir_name, test_name, test_num, only_one_found, simulation_us);

  return 0;
}
