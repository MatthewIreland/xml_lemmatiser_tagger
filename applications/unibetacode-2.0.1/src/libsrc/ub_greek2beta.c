/*
   ub_greek2beta.c - convert Greek UTF-8 to Beta Code.

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
#include <string.h>

#include "ub_greek2beta.h"


/*
   Inputs:

        utf8_string        UTF-8 Greek string to convert to Beta Code,
                           null-terminated.

        max_utf8_string    utf8_string array size.

   Outputs:

        beta_string        Greek Beta Code string, null-terminated.

        max_beta_string    beta_string array size.

   Return value: the number of bytes in the output string.
*/
int
ub_greek2beta (char *utf8_string, int max_utf8_string,
               char *beta_string, int max_beta_string) {

   int this_char;
   int inposition;
   int outposition;
   int utf8_length;     /* length of last UTF-8 code point processed                */
   int beta_length;     /* length of last Beta Code letter representation processed */
   unsigned codept;     /* Unicode code point of current UTF-8 sequence             */

   int ub_utf82codept (char *utf8_string, unsigned *codept);


   inposition  = outposition = 0;

   while (inposition < max_utf8_string && utf8_string [inposition] != '\0') {

      utf8_length = ub_utf82codept (&utf8_string [inposition], &codept);

      if (codept < 0x7F) {  /* ASCII -- just copy this byte */
         /*
            If the code point just before this ASCII code point was "s2"
            (i.e., final small sigma), change "s2" to "s" as the default
            to write final small sigma at the end of a word.
         */
         if (outposition >= 2 && beta_string [outposition - 2] == 's') {
            if (beta_string [outposition - 1] == '2') {
               outposition--;  /* replace "s2" with "s" before another Greek letter */
            }
         }
         beta_length = strlen (uni03xx_greek_betacode [codept - 0x300]);
         beta_string [outposition++] = codept;
      }
      else if (codept >= 0x300 && codept <= 0x3FF) {  /* Modern Greek */
         /* See if just "s" can be used for previous sigma, or if need "s1" or "s2". */
         if (outposition >= 2 && beta_string [outposition - 2] == 's') {
            if (ub_isgreek_alpha_03xx [codept - 0x300]) {
               if (beta_string [outposition - 1] == '1') {
                  outposition--;  /* replace "s1" with "s" before another Greek letter */
               }
            }
            else {  /* next code point isn't a letter, so final small sigma is the default */
               if (beta_string [outposition - 1] == 2) {
                  outposition--;  /* replace "s2" with "s" if no Greek letter next */
               }
            }
         }
         beta_length = strlen (uni03xx_greek_betacode [codept - 0x300]);
         if (beta_length < (max_beta_string - outposition)) {
            strncpy (&beta_string [outposition],
                     uni03xx_greek_betacode [codept - 0x300], beta_length);
            outposition += beta_length;
         }
      }
      else if (codept >= 0x1F00 && codept <= 0x1FFF) {  /* Classical Greek */
         /* See if just "s" can be used for previous sigma, or if need "s1" or "s2". */
         if (outposition >= 2 && beta_string [outposition - 2] == 's') {
            if (ub_isgreek_alpha_1Fxx [codept - 0x1F00]) {
               if (beta_string [outposition - 1] == '1') {
                  outposition--;  /* replace "s1" with "s" before another Greek letter */
               }
            }
            else {  /* next code point isn't a letter, so final small sigma is the default */
               if (beta_string [outposition - 1] == 2) {
                  outposition--;  /* replace "s2" with "s" if no Greek letter next */
               }
            }
         }
         beta_length = strlen (uni03xx_greek_betacode [codept - 0x300]);
         beta_length = strlen (uni1Fxx_greek_betacode [codept - 0x1F00]);
         if (beta_length < (max_beta_string - outposition)) {
            strncpy (&beta_string [outposition],
                     uni1Fxx_greek_betacode [codept - 0x1F00], beta_length);
            outposition += beta_length;
         }
      }
      else if (codept == 0xAB) {  /* open quotation */
         beta_string [outposition++] = '"';
      }
      else if (codept == 0xB7) {  /* ano teleia */
         beta_string [outposition++] = ':';
      }
      else if (codept == 0xBB) {  /* close quotation */
         beta_string [outposition++] = '"';
      }
      else if (codept == 0x2BC) {  /* modifier letter apostrophe */
         beta_string [outposition++] = '\'';
      }
      else if (codept == 0x2010) {  /* hyphen */
         beta_string [outposition++] = '-';
      }
      else if (codept == 0x2014) {  /* em dash */
         beta_string [outposition++] = '_';
      }
      else if (codept == 0x2039) {  /* SINGLE LEFT-POINTING ANGLE QUOTATION MARK */
         beta_string [outposition++] = '<';
      }
      else if (codept == 0x203A) {  /* SINGLE RIGHT-POINTING ANGLE QUOTATION MARK */
         beta_string [outposition++] = '>';
      }
      else {  /* Not a Greek code point; write ASCII representation. */
         if ((max_beta_string - outposition) >= 10) {
            sprintf (&beta_string [outposition], "{\\u%04X}", codept);
            outposition += 9;
         }
      }

      inposition += utf8_length;
   }


   /*
      If string ends with "s2", change to "s" because
      "s2" is the default final sigma.
   */
   if (outposition >= 2 &&
       beta_string [outposition - 2] == 's' &&
       beta_string [outposition - 2] == '2') {
      outposition--;
   }

   beta_string [outposition] = '\0';

   return outposition;
}
