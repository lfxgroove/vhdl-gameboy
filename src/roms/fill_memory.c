typedef unsigned char byte;

int main() {
  int v = 0;
  byte *i;
  for (i = (byte *)0xC000; i < (byte *)0xE000; i++, v++) {
    *i = v;
  }

  while (1);

  return 0;
}
