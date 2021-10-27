/*
   ub_beta2hebrew.h - tables to convert from Beta Code
                      to Unicode in Hebrew.

   Author: Paul Hardy, unifoundry <at> unifoundry.com

   Copyright (C) 2018, 2019, 2020 Paul Hardy

   LICENSE:

      This program is free software: you can redistribute it and/or modify
      it under the terms of the GNU General Public License as published by
      the Free Software Foundation, either version 2 of the License, or
      (at your option) any later version.

      This program is distributed in the hope that it will be useful,
      but WITHOUT ANY WARRANTY; without even the implied warranty of
      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
      GNU General Public License for more details.
      You should have received a copy of the GNU General Public License
      along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
   Table to convert an ASCII letter into a Hebrew Unicode letter.
*/
unsigned ascii2hebrew[128] = {
/*   0/8    1/9    2/A    3/B    4/C    5/D    6/E    7/F   */
       0,     0,     0,     0,     0,     0,     0,     0,  /* 0x00..0x07 */
       0,  '\t',  '\n',     0,     0,     0,  '\r',     0,  /* 0x08..0x0F */
       0,     0,     0,     0,     0,     0,     0,     0,  /* 0x10..0x17 */
       0,     0,     0,     0,     0,     0,     0,     0,  /* 0x18..0x1F */
     ' ',   '!',   '"',   '#',   '$',   '%',   '&',0x2018,  /* 0x20..0x27  !"#$%&' */
     '(',   ')',   '*',   '+',   ',',0x2010,   '.',   '/',  /* 0x28..0x2F ()*+,-./ */
     '0',   '1',   '2',   '3',   '4',   '5',   '6',   '7',  /* 0x30..0x37 01234567 */
     '8',   '9',   ':',   ';',   '<',   '=',   '>',   '?',  /* 0x38..0x3F 89:;<=>? */
     '@', 0x5D0,     0,     0,     0,     0,     0,     0,  /* 0x40..0x47 @ABCDEFG */
   0x5D7,     0,     0,     0,     0,     0,     0,     0,  /* 0x48..0x4F HIJKLMNO */
       0, 0x5D8,     0, 0x5E1, 0x5E6,     0,     0,     0,  /* 0x50..0x57 PQRSTUVW */
       0,     0,     0,   '[',  '\\',   ']',   '^',0x2014,  /* 0x58..0x5F XYZ[\]^_ */
  0x201A, 0x5E2, 0x5D1,     0, 0x5D3,     0,     0, 0x5D2,  /* 0x60..0x67 `abcdefg */
   0x5D4,     0,     0, 0x5DB, 0x5DC, 0x5DE, 0x5E0,     0,  /* 0x68..0x6F hijklmno */
   0x5E4, 0x5E7, 0x5E8, 0x5E9, 0x5EA,     0, 0x5D5,     0,  /* 0x70..0x77 pqrstuvw */
       0, 0x5D9, 0x5D6,   '{',   '|',   '}',   '~',     0   /* 0x78..0x7F xyz{|}~<DEL> */
/*   0/8    1/9    2/A    3/B    4/C    5/D    6/E    7/F   */
};


