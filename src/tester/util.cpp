#include "util.hpp"

std::string Util::to_bin(int i)
{
  //Convert from decimal to binary format
  //This isn't the best but it gets the job done atm

  std::vector<char> data;
  while (i > 0)
    {
      if (i % 2 == 0)
	data.push_back('0');
      else
	data.push_back('1');
      i /= 2;
    }
  
  while (data.size() < 8)
    data.push_back('0');
  
  std::reverse(data.begin(), data.end());
  std::string ret_val;
  std::copy(data.begin(), data.end(), std::back_inserter(ret_val));
  return ret_val;
}
