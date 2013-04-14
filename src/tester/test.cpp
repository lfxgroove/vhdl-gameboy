#include "test.hpp"


Test::Test()
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

void Test::reset()
{
  m_prepare.clear();
  m_test_addresses.clear();
  m_check_addresses.clear();
}

bool Test::run()
{
  //Generate a file and give it to the vhdl program
  return false;
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
