#pragma once

#include <iostream>
#include <iomanip>
#include <fstream>
#include <list>
#include <vector>
#include <cmath>
#include <algorithm>
#include "typedefs.hpp"

class TestFile
{
public:
  TestFile();
  TestFile(Test* t);
  virtual ~TestFile();
  
  void generate_input();
  //This takes care of generating data from 
  //the tests get_test_addr_data()
  bool generate_test_data();
  void fill(const std::string& file_name);
  
  //Start address where we want to start in ROM
  static const int START_ADDR = 0x150;
  static const int EMPTY_OPCODE = 0x00;
  
private:
  //Pads the m_curr_addr up to to
  // (fills with 0x0)
  void pad_addr(int to);
  void add_bytes(AddrDatas::iterator& it);
  void add_bytes(AddrDatas::const_iterator& it);
  
  std::string to_bin(int i);
  
  Test* m_test;
  int m_curr_addr;
  //Bytes that we're going to write later
  std::list<byte> m_bytes;
};
