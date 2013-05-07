#include "parser.hpp"

const std::string Parser::PREPARE_IDENTIFIER = "prepare";
const std::string Parser::TEST_IDENTIFIER = "test";
const std::string Parser::CHECK_IDENTIFIER = "check";

Parser::Parser() 
  : m_block(BLOCK_UNDEFINED),
    m_state(STATE_NEED_IDENTIFIER),
    m_has_prev_addr(false),
    m_in_addr(false)
{}

Parser::Parser(Tokenizer& t, const std::string& base_path)
  : m_block(BLOCK_UNDEFINED),
    m_state(STATE_NEED_IDENTIFIER),
    m_current_test(base_path),
    m_tokenizer(t),
    //TODO: Remove m_has_prev_addr,  not used anymore
    m_has_prev_addr(false),
    m_in_addr(false),
    m_base_path(base_path)
{}

Parser::Parser(const Parser& rhs)
{}

Tests Parser::parse()
{
  std::cout << "Parsing tests.. " << std::flush;
  while (m_tokenizer.has_token())
    {
      // m_tokenizer.next();
      if (m_tokenizer.is_comment())
      	{
	  parse_comment();
      	}
      
      if (m_tokenizer.is_identifier())
      	{
      	  // std::cout << "Found identifier: " << m_tokenizer.current() << ", "
      	  // 	    << m_tokenizer.pos_x() << ":" <<m_tokenizer.pos_y() << std::endl;
	  m_tokenizer.next();
	  parse_identifier();
      	}
      
      if (m_tokenizer.is_start_block())
	{
	  m_tokenizer.next();
	  switch (m_block)
	    {
	    case BLOCK_TEST:
	      //Make sure that we add that last one,
	      //and more importantly reset
	      add_prep_addr();
	      parse_test();
	      break;
	    case BLOCK_CHECK:
	      parse_check();
	      m_block = BLOCK_UNDEFINED;
	      m_current_test.add_prepare(m_prepare);
	      m_current_test.set_prep_addrs(m_prepare_addrs);
	      add_test();
	      break;
	    case BLOCK_PREPARE:
	      parse_prepare();
	      break;
	    }
	}
      m_tokenizer.next();
    }
  
  std::cout << " done" << std::endl;
  // std::cout << "Debug output: " << std::endl
  // 	    << "=======================" << std::endl;;
  // std::cout << *this << std::endl;
  
  return m_current_tests;
}

void Parser::add_test()
{
  if (m_current_test.has_data())
    {
      m_current_tests.push_back(m_current_test);
      m_current_test.reset();
    }
  else
    {
      std::cout << "DEBUG: Test has no data, do you have an empty @test block?" << std::endl;
    }
}

void Parser::add_addr()
{
  if (!m_current_addr.empty())
    {
      if (m_block == BLOCK_CHECK)
	m_current_test.add_check_addr_data(m_current_addr);
      else if(m_block == BLOCK_TEST)
	m_current_test.add_test_addr_data(m_current_addr);
      
      m_current_addr.reset();
    }
}

void Parser::parse_test()
{
  //We expect to find a @check sooner or later
  while (!m_tokenizer.is_end_block())
    {
      if (m_tokenizer.is_comment())
	parse_comment();
      
      if (m_tokenizer.is_identifier())
      	{
	  //Remember to add the last adr parsed
	  //to the data.
	  add_addr();
	  //Kludge..
	  m_tokenizer.next();
	  parse_identifier();
	  break;
      	}
      else
	{
	  if (m_tokenizer.is_start_addr())
	    {
	      add_addr();
	      m_tokenizer.next();
	      parse_addr();
	    }
	  else
	    {
	      parse_byte();
	    }
	}
      m_tokenizer.next();
    }
  //Add the last one aswell
  // add_addr();
}

void Parser::parse_check()
{
  while (!m_tokenizer.is_end_block())
    {
      if (m_tokenizer.is_comment())
	parse_comment();
      
      if (m_tokenizer.is_start_addr())
	{
	  add_addr();
	  m_tokenizer.next();
	  parse_addr();
	}
      else
	{
	  parse_byte();
	}
      m_tokenizer.next();
    }
  add_addr();
  //Now we should find another end block that closes the test
  while (m_tokenizer.has_token())
    {
      if (m_tokenizer.is_comment())
	parse_comment();
      
      if (m_tokenizer.is_end_block())
	break;
      m_tokenizer.next();
    }
  if (!m_tokenizer.has_token())
    {
      std::cout << "DEBUG: You forgot to close either @test or @check" << std::endl;
    }
}

void Parser::add_prep_addr()
{
  if (!m_current_addr.empty() && m_in_addr)
    {
      // std::cout << "LAgger till: " << m_current_addr << "till prep" << std::endl;
      m_prepare_addrs.push_back(m_current_addr);
      m_current_addr.reset();
    }
}

//The prepare block just holds bytes.
void Parser::parse_prepare()
{
  while (!m_tokenizer.is_end_block())
    {
      if (m_tokenizer.is_comment())
	  parse_comment();
      
      if (m_tokenizer.is_start_addr())
	{
	  m_in_addr = true;
	  add_prep_addr();
	  m_tokenizer.next();
	  parse_addr();
	  // add_addr();
	  // m_tokenizer.next();
	  // parse_addr();
	}
      else
	{
	  parse_byte();
	}
      
      // parse_byte();
      m_tokenizer.next();
    }
}

std::ostream & operator<<(std::ostream& os, const Parser& p)
{
  os << "Prepare block (0x150): " << std::endl;
  for (PrepareStatements::const_iterator it = p.m_prepare.begin();
       it != p.m_prepare.end();
       ++it)
    {
      os << std::setbase(16) << std::showbase << std::setw(2) << (int) *it << " "
	 << std::resetiosflags(std::ios_base::basefield | 
			       std::ios_base::adjustfield);
    }
  os << std::endl;
  
  os << "Prepare blocks with addrs: " << std::endl;
  for (AddrDatas::const_iterator it = p.m_prepare_addrs.begin();
       it != p.m_prepare_addrs.end();
       ++it)
    {
      os << *it << std::endl;
    }
  
  os << "Test blocks: " << std::endl;
  int i = 1;
  for (Tests::const_iterator it = p.m_current_tests.begin();
       it != p.m_current_tests.end();
       ++it, ++i)
    {
      os << "Test " << i << std::endl;
      os << *it << std::endl;
    }
  return os;
}

void Parser::parse_comment() 
{
  // std::cout << "DEBUG: Aeter kommentar pa (" << m_tokenizer.pos_x() << ", " << m_tokenizer.pos_y() << ")" << std::endl;
  //Read until end of line
  while (!m_tokenizer.is_end_of_line())
    m_tokenizer.next();
  //Read away that newline!
  // std::cout << "TOKEN:" << m_tokenizer.current() << ":" << std::endl;
  // m_tokenizer.next();
  // std::cout << "TOKEN:" << m_tokenizer.current() << ":" << std::endl;
  
  if (m_tokenizer.is_comment())
    parse_comment();
}

//Code duplication here!
void Parser::parse_addr()
{
  int num_in_row = 0;
  std::stringstream hex_data;
  
  while (!m_tokenizer.is_end_addr())
    {
      if (m_tokenizer.is_comment())
	parse_comment();
      
      hex_data << m_tokenizer.current();
      ++num_in_row;
      if (num_in_row == 4)
	{
	  std::stringstream tmp;
	  unsigned int data;
	  tmp.str("");
	  std::string damp = hex_data.str();
	  tmp << std::hex << damp;
	  tmp >> data;
	  // std::cout << "Data:" << data << std::endl;
	  num_in_row = 0;
	  hex_data.str("");
	  tmp.str("");
	  m_current_addr.set_addr(data);
	  m_has_prev_addr = true;
	}
      m_tokenizer.next();
    }
}

void Parser::parse_byte()
{
  int num_in_row = 0;
  std::stringstream hex_data;
  while (m_tokenizer.is_good_block_data())
    {
      if (m_tokenizer.is_comment())
	parse_comment();
      
      hex_data << m_tokenizer.current();
      ++num_in_row;
      if (num_in_row == 2)
	{
	  std::stringstream tmp;
	  unsigned int data;
	  tmp.str("");
	  std::string damp = hex_data.str();
	  tmp << std::hex << damp;
	  tmp >> data;
	  // std::cout << "Data:" << data << std::endl;
	  num_in_row = 0;
	  hex_data.str("");
	  tmp.str("");
	  if (m_block == BLOCK_PREPARE && !m_in_addr)
	    {
	      // std::cout << "no" << std::hex << m_current_addr.get_addr() << ": " << data << std::dec << std::endl;
	      m_prepare.push_back((byte) data);
	    }
	  else if (m_block == BLOCK_PREPARE && m_in_addr)
	    {
	      // std::cout << std::hex << m_current_addr.get_addr() << ": " << data << std::dec << std::endl;
	      m_current_addr.add_byte(byte(data));
	    }
	  else if (m_block == BLOCK_CHECK || m_block == BLOCK_TEST)
	    {
	      // std::cout << "Lagger till: " << int(data) << " till check/test" << std::endl;
	      m_current_addr.add_byte((byte) data);
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
  // std::cout << "Hittade identifier: " << m_current_data.str() <<  ":" << std::endl;
  m_identifier = m_current_data.str();
  m_current_data.str("");
  //TODO: Remove m_state, m_block superseedes it
  m_state = STATE_NEED_START_BLOCK;
  
  m_prev_block = m_block;
  if (m_identifier == CHECK_IDENTIFIER)
      m_block = BLOCK_CHECK;
  else if (m_identifier == TEST_IDENTIFIER)
    m_block = BLOCK_TEST;
  else if (m_identifier == PREPARE_IDENTIFIER)
    m_block = BLOCK_PREPARE;
}

Parser::~Parser()
{}
