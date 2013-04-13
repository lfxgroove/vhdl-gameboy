#pragma once

#include <iostream>
#include <sstream>

#include "test.hpp"
#include "tokenizer.hpp"
#include "typedefs.hpp"
#include "addrdata.hpp"

enum ParserState
  {
    STATE_NEED_IDENTIFIER,
    STATE_NEED_START_BLOCK,
    STATE_NEED_END_BLOCK,
    STATE_IN_ADDR,
    STATE_IN_CHECK,
    STATE_RECURSE_CHECK
  };

enum BlockState
  {
    BLOCK_TEST,
    BLOCK_CHECK,
    BLOCK_PREPARE,
    BLOCK_UNDEFINED
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
  void parse_block(bool recurse = false);
  void parse_comment();
  void parse_addr();
  void parse_byte();
  
  void update_addr();

  //Debug
  friend std::ostream & operator<<(std::ostream &os, const Parser& t);
  
  //Should probably be replaced with an enum..
  static const std::string PREPARE_IDENTIFIER;
  static const std::string TEST_IDENTIFIER;
  static const std::string CHECK_IDENTIFIER;
  
  BlockState m_block, m_prev_block;
  ParserState m_state;
  std::string m_identifier;
  std::stringstream m_current_data;
  PrepareStatements m_prepare;
  Tests m_current_tests;
  Test m_current_test;
  AddrData m_current_addr;
  Tokenizer m_tokenizer;
  bool m_has_prev_addr;
};
