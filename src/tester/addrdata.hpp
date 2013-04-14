#pragma once

#include <iomanip>
#include <iostream>
#include <list>
#include "typedefs.hpp"

class AddrData
{
public:
  AddrData() {};
  virtual ~AddrData() {};
  
  inline void set_addr(int addr) { m_addr = addr;};
  inline void add_byte(byte data) { m_bytes.push_back(data);};
  //This default value should perhaps be changed
  //Also, find duplicates! That is not good!
  inline void reset() { m_addr = 0x150; m_bytes.clear();};
  inline bool empty() { return m_bytes.empty();};
  
private:
  friend std::ostream & operator<<(std::ostream &os, const AddrData& a);
  
  //At what address should we start
  int m_addr;
  //What to place there
  std::list<byte> m_bytes;
};

