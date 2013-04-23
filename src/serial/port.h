#pragma once

class Port {
public:
  Port(const String &port, int baud);
  ~Port();

  inline bool isOpen() const { return portFd != -1; }

  void write(byte *buffer, nat size);

  //Set as nonblocking. Returns the number of bytes actually read.
  nat read(byte *buffer, nat size);
private:
  int portFd;

  void openPort(const String &port, int baud);
};
