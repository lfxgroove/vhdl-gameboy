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

void fn() {
  byte *src;
  for (src = 0x8000; src < 0x97FF; src++) {
    *src = 0x55;
  }
}

void fn2() {
  byte *src;
  for (src = 0x8000; src < 0x97FF; src++) {
    *src = 0x5F;
  }
}

void main() {
  byte *src, *dest;
  struct obj *o;

  LCD = LCD_ON | LCD_BG_ON | LCD_BG_CHAR_LOW | LCD_BG_CODE_LOW | LCD_OBJ_ON;

  /* for (dest = 0x8000; dest < 0x97FF;) { */
  /*   src = dest; */
  /*   dest += 0x10; */
  /*   for (; src < dest; src++) { */
  /*     *src = at; */
  /*   } */
  /*   at++; */
  /* } */

  fn();
  fn2();

  /* for (src = 0x8010; src < 0x8020; src++) { */
  /*   *src = 0x00; */
  /* } */

  /* at = 0; */
  /* for (src = 0x9800; src < 0x9FFF; src++, at++) { */
  /*   *src = at; */
  /* } */

  for (src = 0xFE00; src < 0xFEA0; src++) {
    *src = 0xFF;
  }

  /* OBJ_NR(0).x = 100; */
  /* OBJ_NR(0).y = 100; */
  /* OBJ_NR(0).character = 0; */
  /* OBJ_NR(0).attribute = 0; */

  /* OBJ_NR(1).x = 100; */
  /* OBJ_NR(1).y = 100; */
  /* OBJ_NR(1).character = 0; */
  /* OBJ_NR(1).attribute = 0; */

  while (1) {}
}
