#pragma once

#include "typedefs.hpp"

#include <list>
#include <iomanip>
#include <iostream>

struct DiffInfo
{
  std::string found, expected;
  int addr;
};

class Diff
{
public:
  Diff();
  virtual ~Diff();
  
  void add_diff(DiffInfo diff);
private:
  friend std::ostream& operator<<(std::ostream &os, const Diff& d);
  DiffList m_diffs;
};
