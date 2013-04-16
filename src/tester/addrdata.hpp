#pragma once

#include <iomanip>
#include <iostream>
#include <list>
#include "typedefs.hpp"

class AddrData
{
public:
  AddrData() : m_addr(0x150) {};
  virtual ~AddrData() {};
  
  inline void set_addr(int addr) { m_addr = addr;};
  inline int get_addr() const { return m_addr;};
  inline void add_byte(byte data) { m_bytes.push_back(data);};
  inline const ByteList& get_bytes() const { return m_bytes;};
  //This default value should perhaps be changed
  //Also, find duplicates! That is not good!
  inline void reset() { m_addr = 0x150; m_bytes.clear();};
  inline bool empty() { return m_bytes.empty();};
  
  inline bool operator<(const AddrData& rhs) const {
    return this->m_addr < rhs.m_addr;
  };
  
  inline bool operator>(const AddrData& rhs) const {
    return rhs < (*this);
  };
  
private:
  friend std::ostream & operator<<(std::ostream &os, const AddrData& a);
  
  //At what address should we start
  int m_addr;
  //What to place there
  ByteList m_bytes;
};

// typedef std::list<AddrData> AddrDatas;
