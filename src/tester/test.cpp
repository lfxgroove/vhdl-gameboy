#include "test.hpp"

Test::Test()
{}

Test::Test(const std::string& base_path)
  : m_base_path(base_path)
{}  

Test::~Test()
{}

void Test::add_prepare(PrepareStatements prep)
{
  m_prepare = prep;
}

void Test::add_check_addr_data(AddrData data)
{
  m_check_addresses.push_back(data);
}

void Test::add_test_addr_data(AddrData data)
{
  m_test_addresses.push_back(data);
}

void Test::set_prep_addrs(AddrDatas data)
{
  m_prep_addresses = data;
}

void Test::reset()
{
  m_prepare.clear();
  m_test_addresses.clear();
  m_check_addresses.clear();
  m_prep_addresses.clear();
}

bool Test::run(const std::string& name)
{
  //Generate a file and give it to the vhdl program
  TestFile tf(this);
  
  tf.generate_input();
  tf.fill(m_base_path + "/stimulus/feed.txt");
  
  //Run the simulation which creates output
  std::string test_name = name;
  std::transform(test_name.begin(), test_name.begin()+1, test_name.begin(), ::toupper);
  for (std::string::iterator it = test_name.begin();
       it != test_name.end();
       ++it)
    {
      if ((*it) == '_')
	std::transform(it+1, it+2, it+1, ::toupper);
    }
  std::string arg = "ghdl --elab-run --ieee=synopsys " 
    + test_name + 
    " --vcd=" + test_name + ".vcd --stop-time=1000us > /dev/null 2>&1";
  std::system(arg.c_str());
  
  return check(m_base_path + "/results/results.txt");
}


void Test::read_num_lines(int num_lines, std::ifstream& file, int& curr_line)
{
  std::array<char, 9> read_to;
  // std::cout << "Laser bort " << std::dec << num_lines << " rader" << std::endl;
  for (int i = 0; i < num_lines; ++i, ++curr_line)
    {
      // std::cout << std::dec <<  i;
      file.getline(&read_to[0], 9);
    }
  // std::cout << std::endl;
}

bool Test::check(const std::string& results_path)
{
  //Open the file
  std::ifstream file;
  file.open(results_path);
  if (!file.is_open())
    {
      std::cout << "DEBUG: Couldn't open " << results_path << std::endl;
    }
  
  m_check_addresses.sort();
  
  int curr_line = 0;
  bool all_ok = true;
  for (AddrDatas::const_iterator it = m_check_addresses.begin();
       it != m_check_addresses.end();
       ++it)
    {
      int addr = it->get_addr();
      if (addr < BASE_CHECK_OFFSET)
	{
	  std::cout << "DEBUG: You are trying to check a value outside" 
		    << " of RAM (0xC000). That won't happen lad" << std::endl;
	  continue;
	}
      read_num_lines(addr - BASE_CHECK_OFFSET - curr_line, file, curr_line);
      
      //next line to read is the one we want to check first
      const ByteList& bytes = it->get_bytes();
      int i = 0;
      for (ByteList::const_iterator it = bytes.begin();
	   it != bytes.end();
	   ++it, ++i, ++curr_line)
	{
	  // 8 + nul
	  std::array<char, 9> read_to;
	  file.getline(&read_to[0], 9);
	  // std::cout << "Read data (" << std::hex << addr + i << "): " << &read_to[0] << std::endl;
	  std::string data;
	  std::copy(read_to.begin(), read_to.end(), std::back_inserter(data));
	  data = data.substr(0, data.size() - 1);
	  // std::cout << "Strangens langd: " << data.size() << " och innehall:" << data << ":" << std::endl;
	  //Get the data that we should diff against
	  if (data != Util::to_bin(int(*it)))
	    {
	      all_ok = false;
	      m_diff.add_diff({data, Util::to_bin(int(*it)), addr + i});
	    }
	  // std::cout << " RAD: " << curr_line << " DATA: " << Util::to_bin(int(*it)) << std::endl;
	}
    }
  return all_ok;
}

std::ostream & operator<<(std::ostream &os, const Test& t)
{
  os << "  Test data:" << std::endl;
  for (AddrDatas::const_iterator it = t.m_test_addresses.begin();
       it != t.m_test_addresses.end();
       ++it)
    {
      os << *it << std::endl;
    }
  os << "  Check data: " << std::endl;
  for (AddrDatas::const_iterator it = t.m_check_addresses.begin();
       it != t.m_check_addresses.end();
       ++it)
    {
      os << *it << std::endl;
    }
  return os;
}
