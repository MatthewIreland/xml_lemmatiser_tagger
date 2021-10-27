/*
   ub_utf8.c - functions to convert between a UTF-32 code point
               and a UTF-8 string.

   Author: Paul Hardy, unifoundry <at> unifoundry.com

   Copyright (C) 2020 Paul Hardy

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

#include <stdio.h>


/*
   ub_codept2utf8 - convert a Unicode code point to a UTF-8 string.

   Input:

        codept        The Unicode code point

   Output:

        utf8_bytes    The converted UTF-8 string, null-terminated,
                      so it must be at least 5 bytes long for full
                      Unicode UTF-8 coverage up to Unicode code
                      point U+10FFFF.

   Return value: length of converted UTF-8 output string.
*/
int
ub_codept2utf8 (unsigned codept, char *utf8_bytes)
{
   int i;              /* loop variable                              */
   int bin_length;     /* number of binary digits, for forming UTF-8 */
   int utf8_length;    /* numberof bytes of UTF-8                    */

   int ub_bin_digits (unsigned);

   utf8_length = 0;  /* no UTF-8 string written yet */


   /*
      If within valid 0x2039Unicode range of U+0000..U+10FFFF, proceed
   */
   if (codept <= 0x10FFFF) {
      bin_length = ub_bin_digits (codept);
      if (bin_length < 8) {        /* U+0000..U+007F */
         utf8_bytes [0] = codept;
         utf8_bytes [1] = '\0';
         utf8_length = 1;
      }
      else if (bin_length < 12) {  /* U+0080..U+07FF */
         utf8_bytes [0] = 0xC0 | ((codept >>  6) & 0x1F);
         utf8_bytes [1] = 0x80 | ( codept        & 0x3F);
         utf8_bytes [2] = '\0';
         utf8_length = 2;
      }
      else if (bin_length < 17) {  /* U+0800..U+FFFF */
         utf8_bytes [0] = 0xE0 | ((codept >> 12) & 0x0F);
         utf8_bytes [1] = 0x80 | ((codept >>  6) & 0x3F);
         utf8_bytes [2] = 0x80 | ( codept        & 0x3F);
         utf8_bytes [3] = '\0';
         utf8_length = 3;
      }
      else if (bin_length < 22) {  /* U+010000..U+10FFFF */
         utf8_bytes [0] = 0xF0 | ((codept >> 18) & 0x07);
         utf8_bytes [1] = 0x80 | ((codept >> 12) & 0x3F);
         utf8_bytes [2] = 0x80 | ((codept >>  6) & 0x3F);
         utf8_bytes [3] = 0x80 | ( codept        & 0x3F);
         utf8_bytes [4] = '\0';
         utf8_length = 4;
      }
      else {
         utf8_length = 0;
      }
   }
   else {
      utf8_length = 0;
   }

   return utf8_length;
}


/*
   ub_bin_digits - determine the number of significant binary digits
                   in an unsigned 32-bit number.

                   Unicode code points will at most have the 21st bit
                   set in a 32-bit word, but start with the 32nd bit
                   as a safeguard against an invalid code point (for
                   example, in case -1 is passed to the function).

   Input:

        itest        The Unicode code point.


   Return value: the number of significant bits in the input code point.
*/
int
ub_bin_digits (unsigned itest)
{
   unsigned i;
   int result;

   itest &= 0xFFFFFFFF;  /* in case "unsigned" is ever > 32 bits  */
   i      = 0x80000000;  /* mask highest 32-bit unsigned bit      */
   result = 32;
   while (  (i != 0) && ((itest & i) == 0) ) {
       i >>= 1;
       result--;
   }

   return result;
}


/*
   ub_utf82codept - convert a UTF-8 byte sequence into a Unicode code point.

   Input:

        utf8_seq      A UTF-8 string, null-terminated, for extracting
                      the first Unicode code point that it contains.

   Output:

        codept        The Unicode code point

   Return value: Length of the first Unicode code point in the UTF-8
                 input string, or -1 if more than the top four bits
                 in the first byte are set (to indicate that this
                 is not a valid UTF-8 byte sequence).

                 Returning the number of bytes in the input string can
                 help if stepping through a string of multiple UTF-8
                 sequences.
*/
int
ub_utf82codept (unsigned char *utf8_seq, unsigned *codept) {

   int i;               /* loop variables                           */
   unsigned mask;       /* bit mask for processing UTF-8 bytes      */
   unsigned this_byte;  /* current byte being processed             */
   int nbytes;          /* return value: length of UTF-8 code point */

   mask      = 0x80;  /* start with masking off high bit in first byte */
   nbytes    =    0;  /* no byte count for UTF-8 sequence yet          */
   *codept   =    0;  /* reset Unicode code point value to 0           */

   this_byte = utf8_seq [0] & 0xFF;

   while ((this_byte & mask) != 0) {
      nbytes++;           /* sequence is one more byte long */
      this_byte ^= mask;  /* turn off current mask bit      */
      mask >>= 1;         /* prepare to examine next bit    */
   }

   *codept = this_byte;  /* high-order bits were already set to 0 */

   if (nbytes == 0) {  /* ASCII -- just return it */
      nbytes  = 1;
   }
   else if (nbytes <= 4) {  /* multi-byte UTF-8 sequence */
      /* Process the remaining UTF-8 bytes. */
      for (i = 1; i < nbytes; i++) {
         this_byte = utf8_seq [i] & 0x3F;  /* mask off top 2 bits           */
         *codept <<= 6;                    /* shift 6 bits per UTF-8 byte   */
         *codept  |= this_byte;            /* high order bits are already 0 */
      }
   }
   else {
      nbytes = -1;  /* Invalid UTF-8 sequence */
   }

   return nbytes;
}
