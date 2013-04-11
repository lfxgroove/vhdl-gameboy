#pragma once

#include <list>

class Test
{
public:
  Test();
  Test(const Test&);
  virtual ~Test();
  
  bool run();
};

