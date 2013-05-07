#include "testfile.hpp"
#include "test.hpp"
  
void TestFile::generate_input() 
{
  //Makefix solution for addrs above 0x150
  AddrDatas& addrs = m_test->get_prep_addr_data_vol();
  addrs.sort();
  
  for (AddrDatas::iterator it = addrs.begin();
       it != addrs.end();
       )//++it)
    {
      int to_addr = it->get_addr();
      if (to_addr > 0x150)
	{
	  pad_addr(0x150);
	  break;
	}
      
      AddrDatas::iterator to_del = it;
      
      if (m_curr_addr < to_addr)
  	{
	  //Get the address up to what we are doing right now
  	  pad_addr(to_addr);
	  add_bytes(it);
	  ++it;
	  addrs.erase(to_del);
  	}
      else if (m_curr_addr == it->get_addr())
  	{
	  add_bytes(it);
	  ++it;
	  addrs.erase(to_del);
  	}
      else
	{
	  ++it;
	}
    }
  
  pad_addr(0x150);

  //Lets  continue with the PrepareStatements
  const PrepareStatements& prep = m_test->get_prepare();
  for (PrepareStatements::const_iterator it = prep.begin();
       it != prep.end();
       ++it)
    {
      m_bytes.push_back(*it);
      ++m_curr_addr;
    }
  
  generate_test_data();
  // if (generate_test_data())
  //   std::cout << "Det gick bra" << std::endl;
  // else
  //   std::cout << "Det gick inte bra" << std::endl;
}

void TestFile::pad_addr(int to)
{
  while (m_curr_addr < to)
    {
      m_bytes.push_back(EMPTY_OPCODE);
      ++m_curr_addr;
    }
}

void TestFile::add_bytes(AddrDatas::iterator& it)
{
  const ByteList& bytes = it->get_bytes();
  for (ByteList::const_iterator it = bytes.begin();
       it != bytes.end();
       ++it)
    {
      // std::cout << std::hex << m_curr_addr << ": " << int(*it) << std::dec << std::endl;
      m_bytes.push_back(*it);
      ++m_curr_addr;
    }
}

void TestFile::add_bytes(AddrDatas::const_iterator& it)
{
  const ByteList& bytes = it->get_bytes();
  for (ByteList::const_iterator it = bytes.begin();
       it != bytes.end();
       ++it)
    {
      // std::cout << std::hex << m_curr_addr << ": " << int(*it) << std::dec << std::endl;
      m_bytes.push_back(*it);
      ++m_curr_addr;
    }
}

bool TestFile::generate_test_data()
{
  AddrDatas addrs = m_test->get_prep_addr_data();
  addrs.sort();
  
  AddrDatas addrs2 = m_test->get_test_addr_data();
  addrs2.sort();
  
  addrs.merge(addrs2);
  
  for (AddrDatas::const_iterator it = addrs.begin();
       it != addrs.end();
       ++it)
    {
      int to_addr = it->get_addr();
      if (m_curr_addr < to_addr)
  	{
	  //Get the address up to what we are doing right now
  	  pad_addr(to_addr);
	  add_bytes(it);
  	}
      else if (m_curr_addr == it->get_addr())
  	{
	  add_bytes(it);
  	}
      else if (m_curr_addr > to_addr)
  	{
	  //Special case that should just be appended to the end of current data
	  if (to_addr == START_ADDR)
	    {
	      add_bytes(it);
	    }
	  else
	    {
	      std::cout << "DEBUG: It would seem that you have placed some test data " 
			<< "where you shouldn't, ie on addr 0x150 (where something el"
			<< "se already is) or something along those lines." << std::endl;
	      std::cout << "This is kinda fatal and will (probably) ruin your test.." << std::endl;
	      return false;
	    }
  	}
    }
  return true;
}

//Convert from decimal to binary format
//This isn't the best but it gets the job done atm
std::string TestFile::to_bin(int i)
{
  std::vector<char> data;
  while (i > 0)
    {
      if (i % 2 == 0)
	data.push_back('0');
      else
	data.push_back('1');
      i /= 2;
    }
  
  while (data.size() < 8)
    data.push_back('0');
  
  std::reverse(data.begin(), data.end());
  std::string ret_val;
  std::copy(data.begin(), data.end(), std::back_inserter(ret_val));
  return ret_val;
}

void TestFile::fill(const std::string& file_name)
{
  std::ofstream file;
  file.open(file_name.c_str());
  if (!file.is_open())
    {
      std::cout << "DEBUG: Couldn't open " << file_name << " for filling" << std::endl;
      return;
    }
  
  for (ByteList::const_iterator it = m_bytes.begin(); 
       it != m_bytes.end();
       ++it)
    {
      //Doesn't work
      // file << std::setbase(2) << int(*it) << std::endl;
      file << to_bin(int(*it)) << std::endl;
    }
  file.close();
  
  // std::cout << "Data: " << std::endl;
  // int addr = 0x150;
  // for (ByteList::const_iterator it = m_bytes.begin(); 
  //      it != m_bytes.end();
  //      ++it, ++addr)
  //   {
  //     std::cout << std::setw(5) << std::hex << addr << ": " 
  // 		<< int(*it) << std::endl;
  //   }
  // std::cout << std::resetiosflags(std::ios_base::basefield | std::ios_base::adjustfield);
  // std::cout << "End data" << std::endl;
}

TestFile::TestFile()
{}

TestFile::TestFile(Test* t)
  : m_test(t),
    m_curr_addr(0x0)
{}

TestFile::~TestFile()
{}
