#include "tokenizer.hpp"

const char Tokenizer::ALLOWED_IDENTIFIER_CHARS[] = 
  {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
    'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-', '_', 0,
  };

//Only hex
const char Tokenizer::ALLOWED_BLOCK_DATA[] = 
  {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'a', 'b', 'c', 'd', 'e', 'f', 
    'A', 'B', 'C', 'D', 'E', 'F', 0
  };

void Tokenizer::next()
{
  m_current_token = m_read_from.get(); 
  //std::cout << "Extracted: " << m_current_token << std::endl;
  //Think about this logic
  ++m_pos_x;
  if (is_end_of_line())
    {
      ++m_pos_y;
      m_pos_x = 1;
    }
}

Tokenizer::Tokenizer()
  : m_pos_x(1), m_pos_y(1)
{}

//Can't call Tokenizer() here since it isn't c++11
Tokenizer::Tokenizer(const std::string& file_name)
  : m_file_name(file_name),
    m_pos_x(1), 
    m_pos_y(1)
{
  m_read_from.open(file_name.c_str());
}

Tokenizer::Tokenizer(const Tokenizer& rhs)
{
  //How could i go about to do this?
  // rhs.m_read_from.close();
  m_read_from.open(rhs.m_file_name.c_str());
  m_file_name = rhs.m_file_name;
  m_pos_x = m_pos_y = 1;
  m_current_token = '\0';
}

Tokenizer::~Tokenizer()
{
  
}
