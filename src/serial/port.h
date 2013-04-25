#pragma once

#ifdef _WIN32
#include <windows.h>
#undef min
#undef max
#endif

class Port {
public:
  Port(const String &port, int baud);
  ~Port();

  bool isOpen() const;

  void write(byte *buffer, nat size);

  //Set as nonblocking. Returns the number of bytes actually read.
  nat read(byte *buffer, nat size);
private:
#ifdef _WIN32
  HANDLE handle;

  void close();
#else
  int portFd;
#endif

  void openPort(const String &port, int baud);
};
