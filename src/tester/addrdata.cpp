#include "addrdata.hpp"


std::ostream & operator<<(std::ostream &os, const AddrData& a)
{
  os << "Start addr: " << a.m_addr << std::endl;
  for (std::list<byte>::const_iterator it = a.m_bytes.begin();
       it != a.m_bytes.end();
       ++it)
    {
      os << std::setw(2) << (int) *it << " ";
    }
  return os;
}
