/*
   ub_beta2greek.c - convert a Greek Beta Code string to a UTF-8 string.

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

#include "ub_beta2greek.h"


/*
   Uncomment only one of the following two defines.
   The first one uses glyphs with tonos from
   U+0370..Y_0377.  The second uses all glyphs
   with oxia (tonos) from U+1F00..U+1FFF.  The
   Unicode Standard recommends using the first
   choice, but if a font was drawn with letters
   noticeably shaped differently from each other
   then the second choice could be visually
   more appealing.
*/
// #define GREEK_COMBINING beta2combining
#define GREEK_COMBINING beta2combining_alt


/*
   ub_beta2greek - convert a Greek Beta Code string to UTF-8.

   Inputs:

        beta_string        Greek Beta Code string, null-terminated.

        max_beta_string    beta_string array size.

   Outputs:

        utf8_string        UTF-8 conversion of Beta Code string,
                           null-terminated.

        max_utf8_string    utf8_string array size.

   Return value: the number of bytes in the output string.
*/
int
ub_beta2greek (char *beta_string, int max_beta_string,
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
   unsigned combining_marks;  /* logic OR of various Greek polytonic combining marks */
   int  quote_state;     /* = 1 if within a set of double quotes, = 0 if not         */
   int  utf8_length;     /* length of last UTF-8 string built from last character    */

   /* Return the next Greek Beta Code character */
   int ub_greek_scanchar (char *beta_string, int max_beta_string,
                          char *beta_char, unsigned *combining_marks);

   /* Convert a Greek Beta Code string to UTF-8 */
   int ub_greek_char2utf8 (char *beta_char, unsigned combining_marks,
                           char *utf8_string, int max_utf8_string);

   /* Output one UTF-8 code point, for special cases */
   int ub_codept2utf8 (unsigned codept, char *utf8_bytes);


   quote_state = 0;                /* not within a double quote pair in this string */
   utf8_length = 0;                /* no UTF-8 output string generated yet          */
   inposition  = outposition = 0;  /* at start of input & output strings            */

   while (inposition < max_beta_string     &&
          beta_string [inposition] != '\0' && 
          outposition < max_utf8_string) {

      scan_length = ub_greek_scanchar (&beta_string [inposition], max_beta_string,
                                    beta_char,  &combining_marks);

      if (beta_char [0] == '"') {
         if (quote_state == 0) {  /* open Greek double quote */
            quote_state = 1;
            scan_length = 1;
            utf8_length = ub_codept2utf8 (0xAB, &utf8_string [outposition]);
         }
         else {  /* close Greek double quote */
            quote_state = 0;
            scan_length = 1;
            utf8_length = ub_codept2utf8 (0xBB, &utf8_string [outposition]);
         }
      }
      else {
         utf8_length = ub_greek_char2utf8 (beta_char, combining_marks,
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
    ub_greek_scanchar - given the current character's Beta Code starting byte
                        (i.e., beta_string[0]), find the last byte for this
                        character.  While scanning, store combining marks.

   Inputs:

        beta_string        Greek Beta Code string, null-terminated.

        max_beta_string    beta_string array size.

   Outputs:

        beta_char           Bytes comprising the next Beta Code character,
                            null-terminated.

        combining_marks     Flags indicating each combining mark present.

   Return value: the number of bytes in the output string.
*/
int
ub_greek_scanchar (char *beta_string, int max_beta_string,
                   char *beta_char, unsigned *combining_marks) {

   int  outposition;     /* start of current output letter without combining marks   */
   int  next_letter;     /* capital letter that preceding combining marks apply to   */
   int  utf8length;      /* return value from UTF-8 conversion                       */
   char thischar;        /* current character being converted                        */
   char utf8_bytes[6];   /* string to hold one UTF-8 character                       */
   int  scan_length;     /* length of current Beta Code polytonic character          */

   unsigned ub_greek_comb2flag (unsigned code_point);

   outposition = 0;
   scan_length = 0;
   *combining_marks = 0;

   thischar = beta_string [0] & 0x7F;

   if (thischar == '*') {  /* Next letter is a capital letter */
      scan_length++;
      do {
         thischar = beta_string [scan_length] & 0x7F;
         if (greek_comb2uni [thischar] > 0) {
            *combining_marks |= ub_greek_comb2flag (greek_comb2uni [thischar]);
            scan_length++;
         }
      }  while (greek_comb2uni [thischar] != 0);

      thischar = beta_string [scan_length] & 0x7F;
      if (isalpha (thischar)) {
         beta_char [outposition++] = toupper (thischar);
         scan_length++;
         thischar = beta_string [scan_length] & 0x7F;
         if (thischar == '|') {
            *combining_marks |= ub_greek_comb2flag (greek_comb2uni [thischar]);
            scan_length++;
         }
      }
   }
   else if (isalpha (thischar)) {  /* lowercase letter */
      beta_char [outposition++] = tolower (thischar);
      scan_length++;
      if (thischar == 'S' || thischar == 's') {

         thischar = beta_string [1] & 0x7F;
         /* Special cases for sigma: s1, s2, s3 */
         if (thischar == '1' || thischar == '2' || thischar == '3') {
            beta_char [outposition++] = thischar;
            scan_length++;
         }
         else {  /* look ahead one position to see if end of word */
            if (isalpha (thischar))
               beta_char [outposition++] = '1';  /* to force to medial sigma */
            else
               beta_char [outposition++] = '2';  /* to force to final sigma */
         }

      }  /* capital or small sigma */
      else {
         do {
            thischar = beta_string [scan_length] & 0x7F;
            if (greek_comb2uni [thischar] > 0) {
               *combining_marks |= ub_greek_comb2flag (greek_comb2uni [thischar]);
               scan_length++;
            }
         }  while (greek_comb2uni [thischar] != 0);
      }  /* letter is sigma */
   }
   else {
      beta_char [outposition++] = thischar;
      scan_length++;
   }
   beta_char [outposition] = '\0';

   return scan_length;
}


/*
   ub_greek_comb2flag - convert a Unicode Greek combining mark
                        to a flag value, for stacking marks.

   Input:

        code_point         Unicode code point.


   Return value: flags indicating polytonic accents present.

*/
unsigned
ub_greek_comb2flag (unsigned code_point) {

   unsigned flag;

   switch (code_point) {
      case 0x0313: flag = UB_GREEK_PSILI;          /* 0x40 smooth breathing   */
                   break;
      case 0x0314: flag = UB_GREEK_DASIA;          /* 0x20 rough breathing    */
                   break;
      case 0x0300: flag = UB_GREEK_VARIA;          /* 0x10 grave accent       */
                   break;
      case 0x0301: flag = UB_GREEK_OXIA;           /* 0x08 acute accent       */
                   break;
      case 0x0342: flag = UB_GREEK_PERISPOMENI;    /* 0x04 circumflex accent  */
                   break;
      case 0x0308: flag = UB_GREEK_DIALYTIKA;      /* 0x02 diaresis           */
                   break;
      case 0x0345: flag = UB_GREEK_YPOGEGRAMMENI;  /* 0x01 iota subscript     */
                   break;                          /* same for prosgegrammeni */
      default:     flag = 0;
                   break;
   }

   return flag;
}


/*
   ub_greek_char2utf8 - output a Greek Beta Code character as a
                        Unicode code point after initial scanning.
                        Before calling this function, medial sigma
                        and final sigma should have been converted
                        into s1 and s2, respectively.

   Inputs:

        beta_char          The current Beta Code character to convert,
                           null-terminated.

        combining_marks    Combining mark flags to look up Unicode
                           code point of pre-formed polytonic glyph.

   Outputs:

        utf8_string        UTF-8 conversion of Beta Code string,
                           null-terminated.

        max_utf8_string    utf8_string array size.

   Return value: the number of bytes in the output string.
*/
int
ub_greek_char2utf8 (char *beta_char, unsigned combining_marks,
                    char *utf8_string, int max_utf8_string) {

   int  i;                  /* loop variable                    */
   char thischar;           /* current letter under examination */
   char nextchar;           /* to check for s1, s2, or s3       */
   int  utf8_length;        /* to return length of UTF-8 string */
   unsigned code_point;     /* Unicode code point               */

   /* Turn polytonic Beta Code letter into Extended Greek code point */
   int ub_greek_poly2utf8 (char *beta_char, unsigned combining_marks,
                           char *utf8_string, int max_utf8_string);

   int ub_codept2utf8 (unsigned codept, char *utf8_string);


   combining_marks &= 0x7F;
   thischar = beta_char [0] & 0x7F;
   utf8_length = 0;             /* no output UTF-8 sequence yet */

   /*
      If there are combining marks, see if one Unicode code point
      exists to encode this Beta Code sequence.
   */
   if (combining_marks == 0) {
      /* Handle special cases for sigma first */
      if (tolower (thischar) == 's') {
         if (thischar == 's') {
            if (beta_char [1] == '1') {
               code_point = 0x03C3;  /* "s1" --> small medial sigma */
            }
            else if (beta_char [1] == '2') {
               code_point = 0x03C2;  /* "s2" --> small final sigma  */
            }
            else if (beta_char [1] == '3') {
               code_point = 0x03F2;  /* "s3" --> small lunate sigma */
            }
            else {
               code_point = 's';     /* convert later as medial or final sigma */
            }
         }
         else {  /* capital sigma */
            if (beta_char [1] == '3') {
               code_point = 0x03F9;  /* "S3" --> capital lunate sigma */
            }
            else {
               code_point = 0x03A3;  /* "S"  --> capital lunate sigma */
            }
         }
      }
      else {  /* not lowercase or uppercase sigma */
         code_point = ascii2greek [thischar];
      }
      utf8_length = ub_codept2utf8 (code_point, utf8_string);
   }
   else {  /* Not sigma, so there's a 1-to-1 mapping from Beta Code to UTF-8 */
      utf8_length = ub_greek_poly2utf8 (
                       beta_char,   combining_marks,
                       utf8_string, max_utf8_string);
      if (utf8_length == 0) {
         /*
            No pre-formed code point existed for this polytonic sequence.
            Generate combining marks one at a time.
         */
         utf8_length += ub_codept2utf8 (beta_char [0], &utf8_string [utf8_length]);
         if (combining_marks != 0) {
            if (combining_marks & UB_GREEK_PSILI) {        /* 0x40 smooth breathing   */
               utf8_length += ub_codept2utf8 (0x313, &utf8_string [utf8_length]);
            }
            if (combining_marks & UB_GREEK_DASIA) {         /* 0x20 rough breathing   */
               utf8_length += ub_codept2utf8 (0x314, &utf8_string [utf8_length]);
            }
            if (combining_marks & UB_GREEK_VARIA) {         /* 0x10 grave accent      */
               utf8_length += ub_codept2utf8 (0x300, &utf8_string [utf8_length]);
            }
            if (combining_marks & UB_GREEK_OXIA) {          /* 0x08 acute accent      */
               utf8_length += ub_codept2utf8 (0x301, &utf8_string [utf8_length]);
            }
            if (combining_marks & UB_GREEK_PERISPOMENI) {   /* 0x04 circumflex accent */
               utf8_length += ub_codept2utf8 (0x342, &utf8_string [utf8_length]);
            }
            if (combining_marks & UB_GREEK_DIALYTIKA) {     /* 0x02 diaresis          */
               utf8_length += ub_codept2utf8 (0x308, &utf8_string [utf8_length]);
            }
            if (combining_marks & UB_GREEK_DIALYTIKA) {     /* 0x02 diaresis          */
               if (isupper (beta_char [0]))   /* Uppercase letter; use prosgegrammeni */
                  utf8_length += ub_codept2utf8 (0x1FBE, &utf8_string [utf8_length]);
               else  /* Not uppercase letter; use ypogegrammeni */
                  utf8_length += ub_codept2utf8 (0x0345, &utf8_string [utf8_length]);
            }
         }
      }
   }
  
   return utf8_length;
}


/*
   ub_greek_poly2utf8 - output a Greek Beta Code character as a
                        Unicode code point after initial scanning.
                        Before calling this function, medial sigma
                        and final sigma should have been converted
                        into s1 and s2, respectively even though
                        sigma is not a vowel.

   Inputs:

        beta_char          The current Beta Code character to convert,
                           null-terminated.

        combining_marks    Combining mark flags to look up Unicode
                           code point of pre-formed polytonic glyph.

   Outputs:

        utf8_string        UTF-8 conversion of Beta Code string,
                           null-terminated.

        max_utf8_string    utf8_string array size.

   Return value: length of UTF-8 string written.
*/
int
ub_greek_poly2utf8 (char *beta_char, unsigned combining_marks,
                    char *utf8_string, int max_utf8_string) {

   int  i;                  /* loop variable                    */
   char thischar;           /* current letter under examination */
   char nextchar;           /* to check for s1, s2, or s3       */
   int  combining_letter;   /* column in GREEK_COMBINING array  */
   unsigned code_point;     /* Unicode code point               */
   int  next_length;        /* next length of UTF-8 output      */
   int  utf8_length;        /* length of UTF-8 string written   */

   int ub_codept2utf8 (unsigned codept, char *utf8_bytes);


   combining_marks &= 0x7F;   /* mask off bits beyond combining flags */
   thischar = beta_char [0];
   utf8_length = 0;  /* no UTF-8 output created yet */

   /*
      If a vowel or rho, see if there are combining marks.
   */
   switch (thischar) {
      case 'A': combining_letter = 0;
                break;
      case 'E': combining_letter = 1;
                break;
      case 'H': combining_letter = 2;
                break;
      case 'I': combining_letter = 3;
                break;
      case 'O': combining_letter = 4;
                break;
      case 'R': combining_letter = 5;
                break;
      case 'U': combining_letter = 6;
                break;
      case 'W': combining_letter = 7;
                break;
      case 'a': combining_letter = 8;
                break;
      case 'e': combining_letter = 9;
                break;
      case 'h': combining_letter = 10;
                break;
      case 'i': combining_letter = 11;
                break;
      case 'o': combining_letter = 12;
                break;
      case 'r': combining_letter = 13;
                break;
      case 'u': combining_letter = 14;
                break;
      case 'w': combining_letter = 15;
                break;
      default:  combining_letter = -1;  /* indicate not in combining array */
                break;
   }

   if (combining_letter >= 0) {
      code_point = GREEK_COMBINING [combining_marks] [combining_letter];
      if (code_point != 0) {
         utf8_length = ub_codept2utf8 (code_point, utf8_string);
      }
      else {
         for (i = 0; beta_char [i] != '\0'; i++) {
            thischar = beta_char [i] & 0x7F;
            next_length = ub_codept2utf8 (thischar, &utf8_string [utf8_length]);
            utf8_length += next_length;
         }
         if (combining_marks & UB_GREEK_DIALYTIKA) {  /* diaresis accent */
            next_length = ub_codept2utf8 (0x0308, &utf8_string [utf8_length]);
            utf8_length += next_length;
         }
         /* Now print the combining characters one at a time */
         if (combining_marks & UB_GREEK_PSILI) {  /* smooth breathing */
            next_length = ub_codept2utf8 (0x0313, &utf8_string [utf8_length]);
            utf8_length += next_length;
         }
         if (combining_marks & UB_GREEK_DASIA) {  /* rough breathing */
            next_length = ub_codept2utf8 (0x0314, &utf8_string [utf8_length]);
            utf8_length += next_length;
         }
         if (combining_marks & UB_GREEK_VARIA) {  /* grave accent */
            next_length = ub_codept2utf8 (0x0300, &utf8_string [utf8_length]);
            utf8_length += next_length;
         }
         if (combining_marks & UB_GREEK_OXIA) {  /* acute accent */
            next_length = ub_codept2utf8 (0x0301, &utf8_string [utf8_length]);
            utf8_length += next_length;
         }
         if (combining_marks & UB_GREEK_PERISPOMENI) {  /* circumflex accent */
            next_length = ub_codept2utf8 (0x0342, &utf8_string [utf8_length]);
            utf8_length += next_length;
         }
         if (combining_marks & UB_GREEK_YPOGEGRAMMENI) { /* iota subscript */
            next_length = ub_codept2utf8 (0x0345, &utf8_string [utf8_length]);
            utf8_length += next_length;
         }
      }
   }

   utf8_string [utf8_length] = '\0';
  
   return utf8_length;
}


