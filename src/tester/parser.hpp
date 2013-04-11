#pragma once

#include <iostream>
#include <sstream>

#include "test.hpp"
#include "tokenizer.hpp"
#include "typedefs.hpp"

enum ParserState
  {
    STATE_NEED_IDENTIFIER,
    STATE_NEED_START_BLOCK,
    STATE_NEED_END_BLOCK
  };

class Parser
{
public:
  Parser(); 
  Parser(Tokenizer&);
  Parser(const Parser&);
  virtual ~Parser();
  Tests parse();
private:
  void parse_identifier();
  void parse_block();
  
  ParserState m_state;
  std::string m_identifier;
  std::stringstream m_current_data;
  Tests m_current_tests;
  Test m_current_test;
  Tokenizer m_tokenizer;
};
