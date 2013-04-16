#pragma once

#include <list>
#include <iostream>
#include <cstdlib>
#include <algorithm>
#include <string>
#include <array>

#include "addrdata.hpp"
#include "typedefs.hpp"
#include "testfile.hpp"
#include "util.hpp"
#include "diff.hpp"

class Test
{
public:
  Test();
  Test(const std::string& base_path);
  virtual ~Test();
  
  void add_prepare(PrepareStatements val);
  inline const PrepareStatements& get_prepare() const { return m_prepare;};
  void add_test_addr_data(AddrData data);
  inline const AddrDatas& get_test_addr_data() const { return m_test_addresses;};
  void add_check_addr_data(AddrData data);
  inline const AddrDatas& get_check_addr_data() const { return m_check_addresses;};
  void set_prep_addrs(AddrDatas addrs);
  inline const AddrDatas& get_prep_addr_data() const { return m_prep_addresses;};
  void reset();
  
  const Diff& diff() const { return m_diff;};
  
  inline bool has_data() { 
    return !m_prepare.empty() 
      // && !m_test_addresses.empty()
      && !m_check_addresses.empty();
  };
  bool run(const std::string& test_name);
  
  const static int BASE_CHECK_OFFSET = 0xC000;
  
private:
  void read_num_lines(int num_lines, std::ifstream& file, int& curr_line);
  bool check(const std::string& results_path);
  
  friend std::ostream& operator<<(std::ostream &os, const Test& t);
  
  std::string m_base_path;

  PrepareStatements m_prepare;
  AddrDatas m_test_addresses, m_check_addresses, m_prep_addresses;
  Diff m_diff;
};

