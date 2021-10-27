/*
   ub_test.c - test unibetacode library functions.

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
#include <stdlib.h>
#include <string.h>

/*
   Input and output buffer sizes.  As a rule of thumb, make the
   UTF-8 output string at least twice as large as the maximum
   Beta Code input string, and at most three times as large,
   to have enough room for the conversion.

   Each unaccented Greek letter will consist of two UTF-8 bytes,
   and each polytonic Greek letter can consist of three UTF-8
   bytes if a pre-formed glyph exists.  If a pre-formed polytonic
   Greek glyph does not exist for a given Beta Code sequence,
   the UTF-8 will likely be two bytes for each Beta Code byte;
   for example, the erroneous Beta Code sequence "t/|" does not
   have a pre-formed polytonic glyph, so the output would be
   (2 UTF-8 bytes per Beta Code byte) * (3 Beta Code bytes) =
   6 UTF-8 bytes.

   Each Coptic letter will have a UTF-8 string that is up to
   three times the number of Beta Code bytes.

   Each Hebrew letter will have a UTF-8 string that is
   two times the number of Beta Code bytes.
*/
#define MAX_BETA_STRING  1024 /* Beta Code input string maximum length */

#define MAX_UTF8_STRING      3072 /* UTF-8 output string maximum length    */


int
main ()
{
   int i;             /* loop variable for converting UTF-8 to Beta Code  */
   int j;             /* index value for UTF-8 to Beta Code string result */
   int utf8_length;   /* return value from unibetacode library functions  */
   int codept_length; /* return value from ub_utf82codept                 */
   unsigned codept;   /* Unicode code point, from ub_utf82codept          */
   int crosscheck_length;  /* length of round-trip conversion */;

   /* Greek Beta Code input string: */
   static char *greek =
   "\"*)en a)rxh=| e)poi/hsen o( *qeo\\s to\\n ou)rano\\n kai\\ th\\n gh=n.\"";

   /* Coptic Beta Code input string: */
   static char *coptic =
      "\"*kEN OUARXH A\\ F\\NOUt QAMIO\\ N\\TFE NEM PHAOI\"";

   /* Hebrew Beta Code input string: */
   static char *hebrew =
      "\"brAsyt brA Alhym2 At hsm1ym2 vAt hArT2\"";

   char utf82greek  [2 * MAX_UTF8_STRING];  /* UTF-8 to Beta Code conversion */
   char utf82coptic [2 * MAX_UTF8_STRING];  /* UTF-8 to Beta Code conversion */
   char utf82hebrew [2 * MAX_UTF8_STRING];  /* UTF-8 to Beta Code conversion */

   char instring   [MAX_BETA_STRING];  /* input string                 */
   char outstring  [MAX_UTF8_STRING];      /* output string                */
   char crosscheck [MAX_BETA_STRING];  /* round-trip conversion string */

   int  exit_status;                       /* exit status                  */

   int ub_beta2greek  (char *, int, char *, int);
   int ub_beta2coptic (char *, int, char *, int);
   int ub_beta2hebrew (char *, int, char *, int);
   int ub_greek2beta  (char *, int, char *, int);
   int ub_coptic2beta (char *, int, char *, int);
   int ub_hebrew2beta (char *, int, char *, int);


   exit_status = EXIT_SUCCESS;


   /*
      Greek Beta Code to UTF-8 conversion.
   */
   strcpy (instring, greek);
   utf8_length = ub_beta2greek ( instring, MAX_BETA_STRING,
                                  outstring, MAX_UTF8_STRING);
   printf ("\nGreek:\n");
   if (utf8_length > 0) {
      printf ("    %s\n", instring);
      printf ("==> %s\n", outstring);
   }
   else {
      printf ("Beta Code to Greek conversion failed.\n");
      exit_status = EXIT_FAILURE;
   }
   /* Greek UTF-8 to Beta Code round-trip conversion check.  */
   crosscheck_length = ub_greek2beta (outstring,  MAX_UTF8_STRING,
                                      crosscheck, MAX_BETA_STRING);
   printf ("==> %s\n", crosscheck);
   if (strcmp (greek, crosscheck) == 0) {
      printf ("    Round-trip Beta Code ==> Greek ==> Beta Code conversion succeeded.\n");
   }
   else {
      printf ("    Round-trip Beta Code ==> Greek ==> Beta Code conversion failed.\n");
      exit_status = EXIT_FAILURE;
   }


   /*
      Coptic Beta Code conversion.
   */
   strcpy (instring, coptic);
   utf8_length = ub_beta2coptic ( instring, MAX_BETA_STRING,
                                 outstring, MAX_UTF8_STRING);
   printf ("\nCoptic:\n");
   if (utf8_length > 0) {
      printf ("    %s\n", instring);
      printf ("==> %s\n", outstring);
   }
   else {
      printf ("Beta Code to Coptic conversion failed.\n");
      exit_status = EXIT_FAILURE;
   }
   /* Coptic UTF-8 to Beta Code round-trip conversion check.  */
   crosscheck_length = ub_coptic2beta (outstring,  MAX_UTF8_STRING,
                                       crosscheck, MAX_BETA_STRING);
   printf ("==> %s\n", crosscheck);
   if (strcmp (coptic, crosscheck) == 0) {
      printf ("    Round-trip Beta Code ==> Coptic ==> Beta Code conversion succeeded.\n");
   }
   else {
      printf ("    Round-trip Beta Code ==> Coptic ==> Beta Code conversion failed.\n");
      exit_status = EXIT_FAILURE;
   }


   /*
      Hebrew Beta Code conversion.
   */
   strcpy (instring, hebrew);
   utf8_length = ub_beta2hebrew ( instring, MAX_BETA_STRING,
                                 outstring, MAX_UTF8_STRING);
   printf ("\nHebrew:\n");
   if (utf8_length > 0) {
      printf ("    %s\n", instring);
      printf ("==> %s\n", outstring);
   }
   else {
      printf ("Beta Code to Hebrew conversion failed.\n");
      exit_status = EXIT_FAILURE;
   }
   /* Hebrew UTF-8 to Beta Code round-trip conversion check.  */
   crosscheck_length = ub_hebrew2beta (outstring,  MAX_UTF8_STRING,
                                       crosscheck, MAX_BETA_STRING);
   printf ("==> %s\n", crosscheck);
   if (strcmp (hebrew, crosscheck) == 0) {
      printf ("    Round-trip Beta Code ==> Hebrew ==> Beta Code conversion succeeded.\n");
   }
   else {
      printf ("    Round-trip Beta Code ==> Hebrew ==> Beta Code conversion failed.\n");
      exit_status = EXIT_FAILURE;
   }

   putchar ('\n');

   exit (exit_status);
}
