#include <gb/gb.h>


// Various types which might be good to have
typedef unsigned char byte;

void memcpy(byte *dest, byte *src, byte size);

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

#define INTERRUPTS AT(0xFFFF)

//NOTE: This assumes DMA is working. Otherwise change to 0xFE00
//Get/set OBJ
#define OBJ_NR(x) (*((struct obj *)0xC000 + (x)))

void copy_obj() {
  byte i;
  //AT(0xFF46) = 0xD0;
  //Wait approx 160 cycles
  //for (i = 40; i != 0; i--);

  //Do a copy without dma since our cpu does not yet support dma.
  //memcpy(0xFE00, 0xC000, sizeof(struct obj) * 40);
}

//Get/set a sprite's n'th byte. Low characters(0x8000-0x97FF)
#define CHAR_LOW(sprite, n) (*((byte *)0x8000 + (sprite) * (int)16 + (n)))

//Get/set a sprite's n'th byte. High characters(0x8800-0x97FF)
#define CHAR_HIGH(sprite, n) (*((byte *)0x8800 + (sprite) * (int)16 + (n)))

//Get/set the background sprite
#define BG_CODE_LOW(x, y) (*((byte *)0x9800 + (x) + (y) * (int)32))
#define BG_CODE_HIGH(x, y) (*((byte *)0x9C00 + (x) + (y) * (int)32))

//The scaling registers
#define SCX AT(0xFF43)
#define SCY AT(0xFF42)

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

byte get_keys() {
  byte w, r;
  AT(0xFF00) = 0x20;
  for (w = 0; w < 10; w++);
  r = AT(0xFF00) << 4;
  AT(0xFF00) = 0x10;
  for (w = 0; w < 10; w++);
  r |= AT(0xFF00) & 0x0F;
  return r;
}

#define KEY_RIGHT 0x10
#define KEY_LEFT 0x20
#define KEY_UP 0x40
#define KEY_DOWN 0x80
#define KEY_A 0x01
#define KEY_B 0x02
#define KEY_SELECT 0x04
#define KEY_START 0x08

#define DOWN(var, key) (((var) & (key)) == 0)


void set_obj(byte id, byte x, byte y, byte ch, byte attr) {
  struct obj *o = &OBJ_NR(id);
  o->x = x;
  o->y = y;
  o->character = ch;
  o->attribute = attr;
}

#define SCREEN_W 160
#define SCREEN_H 144
