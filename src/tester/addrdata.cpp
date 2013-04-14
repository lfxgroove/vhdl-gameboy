#include "addrdata.hpp"

std::ostream & operator<<(std::ostream &os, const AddrData& a)
{
  os << "    Start addr: " << std::setbase(16) << std::showbase << std::setw(0) << a.m_addr << std::endl;
  os << "    ";
  for (std::list<byte>::const_iterator it = a.m_bytes.begin();
       it != a.m_bytes.end();
       ++it)
    {
      os << std::setbase(16) << std::showbase << std::setw(2) << (int) *it << " "
	 << std::resetiosflags(std::ios_base::basefield | 
			       std::ios_base::adjustfield);
    }
  return os;
}
