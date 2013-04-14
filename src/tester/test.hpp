#pragma once

#include <list>
#include <iostream>
#include "addrdata.hpp"
#include "typedefs.hpp"

class Test
{
public:
  Test();
  virtual ~Test();
  
  void add_prepare(PrepareStatements val);
  void add_test_addr_data(AddrData data);
  void add_check_addr_data(AddrData data);
  void reset();
  
  inline bool has_data() { 
    return !m_prepare.empty() 
      && !m_test_addresses.empty()
      && !m_check_addresses.empty();
  };
  bool run();
  
private:
  friend std::ostream & operator<<(std::ostream &os, const Test& t);
  
  PrepareStatements m_prepare;
  AddrDatas m_test_addresses, m_check_addresses;
};

