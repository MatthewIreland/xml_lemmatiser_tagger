/*
   ub_hebrew2beta.c - convert Hebrew UTF-8 to Beta Code.

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

#include "ub_hebrew2beta.h"


/*
   Inputs:

        utf8_string        UTF-8 Hebrew string to convert to Beta Code,
                           null-terminated.

        max_utf8_string    utf8_string array size.

   Outputs:

        beta_string        Hebrew Beta Code string, null-terminated.

        max_beta_string    beta_string array size.

   Return value: the number of bytes in the output string.
*/
int
ub_hebrew2beta (char *utf8_string, int max_utf8_string,
                char *beta_string, int max_beta_string) {

   int this_char;
   int inposition;
   int outposition;
   int utf8_length;  /* length of last UTF-8 code point processed                */
   int beta_length;  /* length of last Beta Code letter representation processed */
   unsigned codept;

   int ub_utf82codept (char *utf8_string, unsigned *codept);


   inposition = outposition = 0;

   while (inposition < max_utf8_string && utf8_string [inposition] != '\0') {

      utf8_length = ub_utf82codept (&utf8_string [inposition], &codept);

      if (codept < 0x7F) {  /* ASCII -- just copy this byte */
         beta_string [outposition++] = codept;
      }
      else if (codept >= 0x590 && codept <= 0x5FF) {  /* Modern Hebrew */
         beta_length = strlen (uni05xx_hebrew_betacode [codept - 0x590]);
         if (beta_length < (max_beta_string - outposition)) {
            strncpy (&beta_string [outposition],
                     uni05xx_hebrew_betacode [codept - 0x590], beta_length);
            outposition += beta_length;
         }
      }
      else {  /* Not a Hebrew code point; write ASCII representation. */
         if ((max_beta_string - outposition) >= 10) {
            sprintf (&beta_string [outposition], "{\\u%04X}", codept);
            outposition += 9;
         }
      }

      inposition += utf8_length;
   }

   beta_string [outposition] = '\0';

   return outposition;
}
