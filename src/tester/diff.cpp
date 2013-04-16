#include "diff.hpp"

std::ostream& operator<<(std::ostream& os, const Diff& d)
{
  for (DiffList::const_iterator it = d.m_diffs.begin();
       it != d.m_diffs.end();
       ++it)
    {
      os << "At addr: " << std::setw(10) << std::hex << it->addr << std::dec 
	 << " expected: " << it->expected << " got: " << it->found << std::endl;
    }
  return os;
}

void Diff::add_diff(DiffInfo diff)
{
  m_diffs.push_back(diff);
}

Diff::Diff()
{}

Diff::~Diff()
{}

