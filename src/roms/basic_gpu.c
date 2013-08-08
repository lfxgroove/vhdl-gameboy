/*
Copyright (c) 2013, Filip Strömbäck, Anton Sundblad, Alex Telon
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * The names of the contributors may not be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL FILIP STRÖMBÄCK, ANTON SUNDBLAD OR ALEX TELON 
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
STRICT LIABILITY, OR TORT(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

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

//NOTE: This assumes DMA is working. Otherwise change to 0xFE00
//Get/set OBJ
#define OBJ_NR(x) (*((struct obj *)0xC000 + (x)))

void copy_obj() {
  byte i;
  AT(0xFF46) = 0xC0;
  //Wait approx 160 cycles
  for (i = 40; i != 0; i--);

  //Do a copy without dma since our cpu does not yet support dma.
  memcpy(0xFE00, 0xC000, sizeof(struct obj) * 40);
}

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

const byte lt_grey_sprite[] = {
  0x00, 0xFF,
  0x00, 0xFF,
  0x00, 0xFF,
  0x00, 0xFF,
  0x00, 0xFF,
  0x00, 0xFF,
  0x00, 0xFF,
  0x00, 0xFF,
};

const byte overlay_sprite[] = {
  0x3B, 0xFB,
  0x3B, 0xFB,
  0x3B, 0xFB,
  0x3B, 0xFB,
  0x3B, 0xFB,
  0x3B, 0xFB,
  0x3B, 0xFB,
  0x3B, 0xFB,
};

void wait() {
  byte a, b;
  for (a = 0; a != 0x0F; a++) {
    for (b = 0; b != 0xFF; b++);
  }
}

void main() {
  int i = 0;
  struct obj *o;

  LCD = LCD_ON | LCD_BG_ON | LCD_BG_CHAR_LOW | LCD_BG_CODE_LOW | LCD_OBJ_ON;

  //Wait until the LCD turns off
  while (STAT & 0x3 != 0);

  set_sprite(white_sprite, 0);
  set_sprite(black_sprite, 1);
  set_sprite(grey_sprite, 2);
  set_sprite(lt_grey_sprite, 3);
  set_sprite(overlay_sprite, 4);

  for (i = 0; i < 32 * 18; i++) {
    BG_CODE_LOW(i, 0) = 0;
  }

  BG_CODE_LOW(5, 5) = 1;
  BG_CODE_LOW(10, 10) = 2;

  //NOTE: The sprites are not currently working on an emulator...

  for (i = 0; i < 40; i++) {
    o = &OBJ_NR(i);
    o->y = o->x = 0xFF;
  }

  o = &OBJ_NR(0);
  o->x = 0;
  o->y = 0;
  o->character = 4;
  o->attribute = OBJ_FRONT | OBJ_LOW_PALETTE;

  o = &OBJ_NR(1);
  o->x = 0;
  o->y = 0;
  o->character = 3;
  o->attribute = OBJ_BACK | OBJ_LOW_PALETTE;

  o = &OBJ_NR(2);
  o->x = 0;
  o->y = 0;
  o->character = 3;
  o->attribute = OBJ_FRONT | OBJ_LOW_PALETTE;

  copy_obj();

  while (1) {
    byte at;
    for (at = 8; at < 160; at++) {
      OBJ_NR(0).x = at;
      OBJ_NR(0).y = at;
      OBJ_NR(1).x = at - 5;
      OBJ_NR(1).y = at - 5;
      OBJ_NR(2).x = at;
      OBJ_NR(2).y = at - 4;

      SCX = SCY = at >> 2;

      wait();
      copy_obj();
    }

    for (at = 160; at > 8; at--) {
      OBJ_NR(0).x = at;
      OBJ_NR(0).y = at;
      OBJ_NR(1).x = at - 5;
      OBJ_NR(1).y = at - 5;
      OBJ_NR(2).x = at;
      OBJ_NR(2).y = at - 4;

      SCX = SCY = at >> 2;

      wait();
      copy_obj();
    }
  }
}
>
