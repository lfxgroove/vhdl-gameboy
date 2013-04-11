#include "parser.hpp"

Parser::Parser() 
  : m_state(STATE_NEED_IDENTIFIER)
{
  
}

Parser::Parser(Tokenizer& t)
  : m_state(STATE_NEED_IDENTIFIER),
    m_tokenizer(t)
{}

Parser::Parser(const Parser& rhs)
{
  
}

Tests Parser::parse()
{
  while (m_tokenizer.has_token())
    {
      m_tokenizer.next();
      if (m_tokenizer.is_comment())
      	{
      	  //Read until end of line
      	  while (!m_tokenizer.is_end_of_line())
      	    m_tokenizer.next();
      	  //Read away that newline!
      	  m_tokenizer.next();
      	}
      
      if (m_tokenizer.is_identifier())
      	{
      	  std::cout << "Found identifier: " << m_tokenizer.current() << ", "
      		    << m_tokenizer.pos_x() << ":" <<m_tokenizer.pos_y() << std::endl;
	  m_tokenizer.next();
	  parse_identifier();
      	}
      
      if (m_tokenizer.is_start_block())
	{
	  m_tokenizer.next();
	  parse_block();
	}
    }
  return Tests();
}

void Parser::parse_block()
{
  int num_in_row = 0;
  std::stringstream hex_data, tmp;
  if (m_state != STATE_NEED_START_BLOCK)
    {
      std::cout << "DEBUG: Start block without any identifier, stupid?" << std::endl;
    }
  m_state = STATE_NEED_END_BLOCK;
  while (!m_tokenizer.is_end_block())
    {
      if (m_tokenizer.is_good_block_data())
	{
	  // std::cout << m_tokenizer.current() << " is good data" << std::endl;
	  hex_data << m_tokenizer.current();
	  ++num_in_row;
	  if (num_in_row == 2)
	    {
	      unsigned int data;
	      std::cout << "Hora:" << hex_data.str() << ":" << std::endl;
	      tmp.str("");
	      std::string damp = hex_data.str();
	      std::cout << "Grek:" << damp << ":" << std::endl;
	      tmp << std::hex << damp << "ANUS";
	      std::cout << "SS:" << tmp.str() << ":" << std::endl;
	      tmp >> data;
	      std::cout << "Data:" << data << std::endl;
	      num_in_row = 0;
	      hex_data.str("");
	      tmp.str("");
	    }
	}
      m_tokenizer.next();
    }
}

void Parser::parse_identifier()
{
  std::string identifier;
  while (m_tokenizer.is_good_identifier())
    {
      m_current_data << m_tokenizer.current();
      m_tokenizer.next();
    }
  std::cout << "Hittade identifier: " << m_current_data.str() <<  ":" << std::endl;
  m_identifier = m_current_data.str();
  m_state = STATE_NEED_START_BLOCK;
}

Parser::~Parser()
{}
