#include "stdafx.h"

#include "port.h"

#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>

#include <iostream>
#include <fstream>

void setrts(int fd, int on) {
  int controlbits;

  ioctl(fd, TIOCMGET, &controlbits);
  if (on) {
    controlbits |= TIOCM_RTS;
  } else {
    controlbits &= ~TIOCM_RTS;
  }
  ioctl(fd, TIOCMSET, &controlbits);
}


/*
 * Set or Clear DTR modem control line
 *
 * Note: TIOCMBIS: CoMmand BIt Set
 * TIOCMBIC: CoMmand BIt Clear
 *
 */
void setdtr (int fd, int on) {
  int controlbits = TIOCM_DTR;
  ioctl(fd, (on ? TIOCMBIS : TIOCMBIC), &controlbits);
}

Port::Port(const String &port, int baud) {
  portFd = -1;

  openPort(port, baud);
}

Port::~Port() {
  if (portFd != -1) {
    close(portFd);
  }
}

nat Port::read(byte *buffer, nat size) {
  int r = ::read(portFd, buffer, size);
  if (r < 0) return 0;
  return nat(r);
}

void Port::write(byte *buffer, nat size) {
  ::write(portFd, buffer, size);
}


tcflag_t getBaudrate(int rate) {
  switch (rate) {
  case 50:
    return B50;
  case 75:
    return B75;
  case 110:
    return B110;
  case 134:
    return B134;
  case 150:
    return B150;
  case 200:
    return B200;
  case 300:
    return B300;
  case 600:
    return B600;
  case 1200:
    return B1200;
  case 1800:
    return B1800;
  case 2400:
    return B2400;
  case 4800:
    return B4800;
  case 9600:
    return B9600;
  case 19200:
    return B19200;
  case 38400:
    return B38400;
  case 57600:
    return B57600;
  case 115200:
    return B115200;
  case 230400:
    return B230400;
  default:
    std::cerr << "Invalid baudrate specified!" << std::endl;
    return B0;
  }
}

void Port::openPort(const String &port, int baud) {
  DEBUG("Opening port " << port << " at " << baud << " baud");
  portFd = open(port.c_str(), O_RDWR | O_NOCTTY | O_NDELAY);
  if (portFd == -1) {
    std::cerr << "Error opening port!" << std::endl;
    return;
  }

  struct termios options;
  tcgetattr(portFd, &options);
  cfsetispeed(&options, getBaudrate(baud));
  cfsetospeed(&options, getBaudrate(baud));
  options.c_cflag |= (CLOCAL | CREAD);
  options.c_cflag &= ~PARENB;
  options.c_cflag &= ~CSTOPB;
  options.c_cflag &= ~CSIZE;
  options.c_cflag &= ~CRTSCTS;
  options.c_cflag |= CS8;
  //options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
  options.c_lflag = 0;
  options.c_cc[VTIME] = 1;
  options.c_cc[VMIN] = 0;
  cfmakeraw(&options);
  tcsetattr(portFd, TCSANOW, &options);

  fcntl(portFd, F_SETFL, FNDELAY);

  setrts(portFd, false);
  setdtr(portFd, false);
}

