
// Various types which might be good to have
typedef unsigned char byte;

//OBJ:s. Located from address 0xFE00-0xFEFF
struct obj {
  byte y;
  byte x;
  byte character;
  byte attribute;
};

//Character palette of the obj (low 0x8000-0x97FF, high 0x8800-0x9BFF)
#define OBJ_LOW_PALETTE 0x00
#define OBJ_HIGH_PALETTE 0x10

//Flips
#define OBJ_HFLIP 0x20
#define OBJ_VFLIP 0x40

//Priority
#define OBJ_FRONT 0x00
#define OBJ_BACK 0x80

//Get memory address
#define AT(x) (*((byte *)(x)))

//Get/set OBJ
#define OBJ_NR(x) (*((struct obj *)0xFE00 + (x)))

//Get/set a sprite's n'th byte. Low characters(0x8000-0x97FF)
#define CHAR_LOW(sprite, n) (*((byte *)0x8000 + (sprite) * 16 + (n)))

//Get/set a sprite's n'th byte. High characters(0x8800-0x97FF)
#define CHAR_HIGH(sprite, n) (*((byte *)0x8800 + (sprite) * 16 + (n)))

//Get/set the background sprite
#define BG_CODE_LOW(x, y) (*((byte *)0x9800 + (x) + (y) * 32))
#define BG_CODE_HIGH(x, y) (*((byte *)0x9C00 + (x) + (y) * 32))

//The scaling registers
#define SCX AT(0xFF42)
#define SCY AT(0xFF43)

//LCD register
#define LCD AT(0xFF40)

//LCD status register
#define STAT AT(0xFF41)
  
//LCD on
#define LCD_ON 0x80
//Window on, the low address in use (0x9800-0x9BFF)
#define LCD_WINDOW_LOW 0x4
//Window on, the high address in use (0x9C00-0x9FFF)
#define LCD_WINDOW_HIGH 0x6
//Background character data, low (0x8000-0x97FF)
#define LCD_BG_CHAR_LOW 0x10
//Background character data, high (0x8800-0x97FF)
#define LCD_BG_CHAR_HIGH 0x00
//Background code, use low addresses (0x9800-0x9BFF)
#define LCD_BG_CODE_LOW 0x0
//Background code, use high addresses (0x9C00-0x9FFF)
#define LCD_BG_CODE_HIGH 0x8
//OBJ size. Use 8x16 sprites
#define LCD_OBJ_LARGE 0x4
//OBJ on
#define LCD_OBJ_ON 0x2
//Background on?
#define LCD_BG_ON 0x1

//Simple memcpy
void memcpy(byte *dest, byte *src, byte size) {
  byte at;
  for (at = 0; at < size; at++) {
    *dest = *src;
    dest++; src++;
  }
}

void set_sprite(byte *from, byte id) {
  memcpy(&CHAR_LOW(id, 0), from, 16);
}


//END OF "LIBRARY"

const byte black_sprite[] = {
  0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF,
  0xFF, 0xFF
};

const byte white_sprite[] = {
  0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00,
  0x00, 0x00
};

const byte grey_sprite[] = {
  0xFF, 0x00,
  0xFF, 0x00,
  0xFF, 0x00,
  0xFF, 0x00,
  0xFF, 0x00,
  0xFF, 0x00,
  0xFF, 0x00,
  0xFF, 0x00,
};

void main() {
  int i = 0;
  struct obj *o;

  LCD = LCD_ON | LCD_BG_ON | LCD_BG_CHAR_LOW | LCD_BG_CODE_LOW | LCD_OBJ_ON;

  //Wait until the LCD turns off
  while (STAT & 0x3 != 0);

  set_sprite(white_sprite, 0);
  set_sprite(black_sprite, 1);
  set_sprite(grey_sprite, 2);

  for (i = 0; i < 32 * 18; i++) {
    BG_CODE_LOW(i, 0) = 0;
  }

  BG_CODE_LOW(5, 5) = 1;
  BG_CODE_LOW(10, 10) = 2;

  //NOTE: The sprites are not currently working on an emulator...

  for (i = 0; i < 40; i++) {
    while (STAT & 0x03 == 0);
    while (STAT & 0x03 != 0);

    o = &OBJ_NR(i);
    o->y = o->x = 0xFF;
  }

  o = &OBJ_NR(0);
  o->x = 30;
  o->y = 30;
  o->character = 2;
  o->attribute = OBJ_FRONT | OBJ_LOW_PALETTE;


  //I do not know what will happen if we exit main... Don't let it happen!
  while (1) {}
}
