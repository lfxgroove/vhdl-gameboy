#include "stdafx.h"
#include "port.h"

#include <algorithm>
#include <fstream>
#include <cstring>
#include <cstdlib>

const nat FILE_SIZE_BYTES = 2;
const nat MAX_FILE_SIZE = 1 << (FILE_SIZE_BYTES * 8) - 1;
const nat CHUNK = 1024;

void printHelp(char *name) {
  DEBUG(name << " [port] [-b baud] [file]");
}

int main(int argc, char **argv) {
  String port, file;
  int baud = 115200;

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-b") == 0) {
      baud = atoi(argv[++i]);
    } else if (port == "") {
      port = argv[i];
    } else if (file == "") {
      file = argv[i];
    } else {
      printHelp(argv[0]);
      return 1;
    }
  }

  if (port == "" || file == "") {
    printHelp(argv[0]);
    return 2;
  }

  Port p(port, baud);
  if (!p.isOpen()) {
    DEBUG("Failed to open port: " << port);
    return 3;
  }

  std::ifstream f(file.c_str(), std::ios::binary);
  if (!f.is_open()) {
    DEBUG("Error: Failed to open: " << file);
    return 6;
  }
  f.seekg(0, std::ios::end);
  nat size = f.tellg();
  f.seekg(0);
  nat sent = 0;

  //Some checks here....
  if (size > MAX_FILE_SIZE) {
    DEBUG("Error: The file is too large: " << size << ", max is: " << MAX_FILE_SIZE);
    return 4;
  }

  DEBUG("Sending " << file << " to " << port << " at " << baud << " baud...");

  //Calculate a simple checksum
  byte checksum = 0;

  //Send size. LSB first.
  nat s = size;
  byte buffer[CHUNK];
  for (int i = 0; i < FILE_SIZE_BYTES; i++) {
    byte b = s & 0xFF;
    s = s >> 8;
    p.write(&b, 1);
  }

  //Send the actual data.
  std::cout << "Sending..." << std::flush;
  while (sent < size) {
    nat toSend = std::min(size - sent, CHUNK);
    f.read((char *)buffer, toSend);
    p.write(buffer, toSend);
    sent += toSend;

    for (nat i = 0; i < toSend; i++) {
      checksum += buffer[i];
    }

    std::cout << "\rSending..." << sent << "/" << size << " bytes" << std::flush;
  }
  std::cout << std::endl;

  //Send checksum
  p.write(&checksum, 1);

  DEBUG("Done!");

  return 0;
}
