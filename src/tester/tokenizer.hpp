#pragma once

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <algorithm>

class Tokenizer
{
public:
  Tokenizer();
  Tokenizer(const std::string& file_name);
  Tokenizer(const Tokenizer&);
  virtual ~Tokenizer();
  
  inline bool is_identifier() const { return m_current_token == '@';};
  inline bool is_comment() const { return m_current_token == '#';};
  inline bool is_start_addr() const { return m_current_token == '[';};
  inline bool is_end_addr() const { return m_current_token == ']';};
  inline bool is_start_block() const { return m_current_token == '{';};
  inline bool is_end_block() const { return m_current_token == '}';};
  inline bool is_space() const { return m_current_token == ' ' || m_current_token == '\t';};
  //This one doesn't work that well..
  inline bool is_end_of_line() const { return m_current_token == '\n' || m_current_token == '\r'; };
  inline bool is_good_identifier() const
  { 
    return std::find(ALLOWED_IDENTIFIER_CHARS.begin(), 
		     ALLOWED_IDENTIFIER_CHARS.end(),
		     m_current_token) != ALLOWED_IDENTIFIER_CHARS.end();
  };
  
  inline bool is_good_block_data() const
  {
    return std::find(ALLOWED_BLOCK_DATA.begin(),
		     ALLOWED_BLOCK_DATA.end(),
		     m_current_token) != ALLOWED_BLOCK_DATA.end();
  };
  
  inline bool has_token() const { return !!m_read_from;};
  void next();
  
  inline int pos_x() const { return m_pos_x;};
  inline int pos_y() const { return m_pos_y;};
  inline char current() const { return m_current_token;};
  
  //Characters allowed in an identifier
  static const std::vector<char> ALLOWED_IDENTIFIER_CHARS;
  static const std::vector<char> ALLOWED_BLOCK_DATA;
  
private:
  std::ifstream m_read_from;
  std::string m_file_name;
  int m_pos_x, m_pos_y;
  char m_current_token;
};

