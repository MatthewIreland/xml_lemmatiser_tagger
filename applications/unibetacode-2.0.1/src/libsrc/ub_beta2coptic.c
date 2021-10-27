/*
   ub_beta2coptic.c - convert a Coptic Beta Code string to a UTF-8 string.

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
#include <ctype.h>

#include "ub_beta2coptic.h"


/*
   ub_beta2coptic - convert a Coptic Beta Code string to UTF-8.

   Inputs:

        beta_string        Coptic Beta Code string, null-terminated.

        max_beta_string    beta_string array size.

   Outputs:

        utf8_string        UTF-8 conversion of Beta Code string,
                           null-terminated.

        max_utf8_string    utf8_string array size.

   Return value: the number of bytes in the output string.
*/
int
ub_beta2coptic (char *beta_string, int max_beta_string,
                char *utf8_string, int max_utf8_string)
{
   int  inposition;      /* start of scan for current output, including combining marks */
   int  outposition;     /* start of current output letter plus combining marks      */
   int  utf8length;      /* return value from UTF-8 conversion                       */
   char thischar;        /* current character being converted                        */
   char thisletter;      /* Latin letter with a Beta Code translation                */
   char beta_char[4];    /* The letter portion of the current polytonic letter       */
   char utf8_bytes[6];   /* string to hold one UTF-8 character                       */
   int  scan_length;     /* length of current Beta Code polytonic character          */
   int  quote_state;     /* = 1 if within a set of double quotes, = 0 if not         */
   unsigned combining_marks;  /* logic OR of various Coptic polytonic combining marks */
   int  utf8_length;     /* length of last UTF-8 string built from last character    */

   /* Return the next Coptic Beta Code character */
   int ub_coptic_scanchar (char *beta_string, int max_beta_string,
                           char *beta_char, unsigned *combining_marks);

   /* Convert a Coptic Beta Code string to UTF-8 */
   int ub_coptic_char2utf8 (char *beta_char, unsigned combining_marks,
                            char *utf8_string, int max_utf8_string);

   /* Output one UTF-8 code point, for special cases */
   int ub_codept2utf8 (unsigned codept, char *utf8_bytes);


   quote_state = 0;                /* not within a double quote pair in this string */
   utf8_length = 0;                /* no UTF-8 output string generated yet          */
   inposition  = outposition = 0;  /* at start of input & output strings            */

   while (inposition < max_beta_string     &&
          beta_string [inposition] != '\0' &&
          outposition < max_utf8_string) {

      scan_length = ub_coptic_scanchar (&beta_string [inposition], max_beta_string,
                                        beta_char,  &combining_marks);

      if (beta_char [0] == '"') {
         if (quote_state == 0) {  /* open Coptic double quote */
            quote_state = 1;
            scan_length = 1;
            utf8_length = ub_codept2utf8 (0xAB, &utf8_string [outposition]);
         }
         else {  /* close Coptic double quote */
            quote_state = 0;
            scan_length = 1;
            utf8_length = ub_codept2utf8 (0xBB, &utf8_string [outposition]);
         }
      }
      else {
         utf8_length = ub_coptic_char2utf8 (beta_char, combining_marks,
                                           &utf8_string [outposition],
                                           max_utf8_string - outposition);
      }

      inposition  += scan_length;
      outposition += utf8_length;
      utf8_string [outposition] = '\0';
   }

   return outposition;
}


/*
    ub_coptic_scanchar - given the current character's Beta Code starting
                         location, find the last byte for this character.
                         While scanning, store combining marks.
   Inputs:

        beta_string        Coptic Beta Code string, null-terminated.

        max_beta_string    beta_string array size.

   Outputs:

        beta_char           Bytes comprising the next Beta Code character,
                            null-terminated.

        combining_marks     Flags indicating each combining mark present.
                            Currently, always returns as zero.  This is
                            included for similarity with the ub_greek_scanchar
                            function.

   Return value: the number of bytes in the output string.
*/
int
ub_coptic_scanchar (char *beta_string, int max_beta_string,
                    char *beta_char, unsigned *combining_marks) {

   int  outposition;     /* start of current output letter without combining marks   */
   int  next_letter;     /* capital letter that preceding combining marks apply to   */
   int  utf8length;      /* return value from UTF-8 conversion                       */
   char thischar;        /* current character being converted                        */
   char utf8_bytes[6];   /* string to hold one UTF-8 character                       */
   int  scan_length;     /* length of current Beta Code polytonic character          */


   outposition = 0;
   scan_length = 0;
   *combining_marks = 0;

   thischar = beta_string [0] & 0x7F;

   beta_char [0] = thischar;
   scan_length = 1;

   if (thischar == '*') {  /* See if next letter is a capital letter */
      if (isalpha (beta_string [1])) {  /* Capital Coptic letter */
         beta_char [1] = beta_string [1];
         scan_length++;
      }
   }

   beta_char [scan_length] = '\0';

   return scan_length;
}


/*
   ub_coptic_comb2flag - convert a Unicode Coptic combining mark
                        to a flag value, for stacking marks.

   This is a placeholder function for similarity with ub_greek_comb2flag.

   Return value is always zero.
*/
unsigned
ub_coptic_comb2flag (unsigned code_point) {

   unsigned flag;

   flag = 0;

   return flag;
}


/*
   ub_coptic_char2utf8 - output a Coptic Beta Code character as a
                         Unicode code point after initial scanning.

   Inputs:

        beta_char          The current Beta Code character to convert,
                           null-terminated.

        combining_marks    Combining mark flags; currently always set
                           to zero.  Provided for similarity with
                           ub_greek_char2utf8.

   Outputs:

        utf8_string        UTF-8 conversion of Beta Code string,
                           null-terminated.

        max_utf8_string    utf8_string array size.

   Return value: the number of bytes in the output string.
*/
int
ub_coptic_char2utf8 (char *beta_char, unsigned combining_marks,
                     char *utf8_string, int max_utf8_string) {

   int  i;                  /* loop variable                    */
   char thischar;           /* current letter under examination */
   char nextchar;           /* to check for s1, s2, or s3       */
   int  utf8_length;        /* to return length of UTF-8 string */
   unsigned code_point;     /* Unicode code point               */

   int ub_codept2utf8 (unsigned codept, char *utf8_string);


   if (beta_char [0] == '*' && isalpha (beta_char [1])) {
      code_point = ascii2coptic [beta_char [1] & 0x7F];
   }
   else if (isalpha (beta_char [0])) {
      code_point = ascii2coptic [beta_char [0] & 0x7F] + 1;
   }
   else {
      code_point = ascii2coptic [beta_char [0] & 0x7F];
   }

   utf8_length = ub_codept2utf8 (code_point, utf8_string);
  
   return utf8_length;
}


/*
   ub_coptic_poly2utf8 - output a Coptic Beta Code character as a
                        Unicode code point after initial scanning.

   Inputs:

        beta_char          The current Beta Code character to convert,
                           null-terminated.

        combining_marks    Combining mark flags; currently always set
                           to zero.  Provided for similarity with
                           ub_greek_char2utf8.

   Outputs:

        utf8_string        UTF-8 conversion of Beta Code string,
                           null-terminated.

        max_utf8_string    utf8_string array size.

   Return value: always set to zero, as there are no Beta Code
   encodings for polytonic marks with Coptic.
*/
int
ub_coptic_poly2utf8 (char *beta_char, unsigned combining_marks,
                    char *utf8_string, int max_utf8_string) {

   return 0;
}


