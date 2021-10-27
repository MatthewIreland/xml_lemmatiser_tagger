/*
   ub_beta2coptic.h - tables to convert from Beta Code
                      to Unicode in Coptic.

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
   Combining mark in Coptic.
*/
#define UB_COPTIC_JINMA		0x01  /* grave accent */


/*
   Table to convert an ASCII letter into a Coptic Unicode letter.

   This table encodes letters that were preceded by a '*'.  If the Latin letter
   was not preceded by a '*', add 1 to get the Unicode code point.
*/
unsigned ascii2coptic[128] = {
/*   0/8     1/9     2/A     3/B     4/C     5/D     6/E     7/F    */
       0,      0,      0,      0,      0,      0,      0,      0,  /* 0x00..0x07 */
       0,   '\t',   '\n',      0,      0,      0,   '\r',      0,  /* 0x08..0x0F */
       0,      0,      0,      0,      0,      0,      0,      0,  /* 0x10..0x17 */
       0,      0,      0,      0,      0,      0,      0,      0,  /* 0x18..0x1F */
     ' ',    '!',    '"',    '#',    '$',    '%',    '&',   '\'',  /* 0x20..0x27  !"#$%&' */
     '(',    ')',    '*',    '+',    ',', 0x2010,    '.',    '/',  /* 0x28..0x2F ()*+,-./ */
     '0',    '1',    '2',    '3',    '4',    '5',    '6',    '7',  /* 0x30..0x37 01234567 */
     '8',    '9',    ':',    ';', 0x2039,    '=', 0x203A,    '?',  /* 0x38..0x3F 89:;<=>? */
     '@', 0x2C80, 0x2C82, 0x2C9C, 0x2C86, 0x2C88, 0x2CAA, 0x2C84,  /* 0x40..0x47 @ABCDEFG */
  0x2C8E, 0x2C92,      0, 0x2C94, 0x2C96, 0x2C98, 0x2C9A, 0x2C9E,  /* 0x48..0x4F HIJKLMNO */
  0x2CA0, 0x2C90, 0x2CA2, 0x2CA4, 0x2CA6, 0x2CA8, 0x2C8A, 0x2CB0,  /* 0x50..0x57 PQRSTUVW */
  0x2CAC,      0, 0x2C8C,    '[', 0x0300,    ']',    '^', 0x2014,   /* 0x58..0x5F XYZ[\]^_ */
     '`',      0,      0,      0,      0,      0, 0x03E4, 0x03EC,  /* 0x60..0x67 `abcdefg */
  0x03E8,      0, 0x03EA, 0x03E6,      0,      0,      0,      0,  /* 0x68..0x6F hijklmno */
       0,      0,      0, 0x03E2, 0x03EE,      0,      0,      0,  /* 0x70..0x77 pqrstuvw */
       0,      0,      0,    '{',    '|',    '}',    '~',      0   /* 0x78..0x7F xyz{|}~<DEL> */
/*   0/8     1/9     2/A     3/B     4/C     5/D     6/E     7/F    */
};


