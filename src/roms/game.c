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
  0x00, 0x00,
  0x3B, 0xFB,
};

void wait() {
  byte a, b;
  for (a = 0; a != 0x0F; a++) {
    for (b = 0; b != 0xFF; b++);
  }
  //TODO: Replace with vsync logic
}

struct player {
  int x, y;
};

struct player player;

#define PLAYER_OBJ 0
#define PLAYER_BITMAP 10

void move() {
  byte keys = readkeys();
  if (DOWN(KEY_UP)) {
    if (player.y > 0) player.y--;
  }
  if (DOWN(KEY_DOWN)) {
    if (player.y < SCREEN_H) player.y++;
  }
  if (DOWN(KEY_LEFT)) {
    if (player.x > 0) player.x--;
  }
  if (DOWN(KEY_RIGHT)) {
    if (player.x < SCREEN_W) player.x++;
  }

  OBJ_NR(PLAYER_OBJ).x = player.x;
  OBJ_NR(PLAYER_OBJ).y = player.y;
}

void timer() {
  OBJ_NR(6).x ++;
}

void main() {
  int i = 0;
  struct obj *o;

  AT(0xFF00) = 0x20;

  INTERRUPTS = 0;

  LCD = LCD_ON | LCD_BG_ON | LCD_BG_CHAR_LOW | LCD_BG_CODE_LOW | LCD_OBJ_ON;

  //Wait until the LCD turns off
  // while (STAT & 0x3 != 0);

  set_sprite(white_sprite, 0);
  set_sprite(player_sprite, PLAYER_BITMAP);
  
  for (i = 0; i < 32 * 32; i++) {
    BG_CODE_LOW(i, 0) = 0;
  }

  set_sprite(PLAYER_OBJ, player.x, player.y, PLAYER_BITMAP, OBJ_LOW_PALETTE | OBJ_FRONT);

  while (1) {
    wait();

    move();
  }
}
