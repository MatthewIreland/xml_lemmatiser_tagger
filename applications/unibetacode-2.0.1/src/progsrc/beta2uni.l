/*
   beta2uni - convert Beta Code to Unicode.

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

%{
#include <stdio.h>
#include <unistd.h>
#include <ctype.h>

/*
   Definitions for Beta Code encoding.
*/
#define LANG_GREEK  0x0000
#define LANG_LATIN  0x1000
#define LANG_COPTIC 0x2000
#define LANG_ARABIC 0x4000  /* Defined by Thesaurus Linguae Graecae but not in their corpus */
#define LANG_HEBREW 0x8000


#define YY_NO_INPUT
#define YY_NO_UNPUT


int bom_out=0;            /* =1 to begin output with a UTF-8 Byte Order Mark (U+FFFE). */
int lang_type=LANG_GREEK; /* For selecting Greek, Latin, Coptic or Hebrew output.      */

int doubleq_style=6;  /* style for double quotation marks (Greek double quotes) */
int singleq_style=7;  /* style for single quotation marks (Greek single quotes) */
/*
   State for quotation type 0 through 9, inclusive; Beta
   Code only uses quotation types 1 through 8, inclusive.

      0 = open quote not active
      1 = open quote active, so next encounter will close this quote
*/
int quote_state[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

/* Unicode character for an opening quote for styles 0 through 9 */
int quote_open[10] = {
   0x201C,  /* 0 */  /* LANG_LATIN:  U+201C LEFT DOUBLE QUOTATION MARK  */
   0x201E,  /* 1 */  /* LANG_HEBREW: U+201E DOUBLE LOW-9 QUOTATION MARK */
   0x201E,  /* 2 */  /*              U+201E DOUBLE LOW-9 QUOTATION MARK (not in TLG spec) */
   0x2018,  /* 3 */  /* LANG_LATIN:  U+2018 LEFT SINGLE QUOTATION MARK  */
   /* 0x02BB   3 */  /* LANG_LATIN:  U+02BB Alternative - MODIFIER LETTER TURNED COMMA */
   0x201A,  /* 4 */  /* LANG_HEBREW: U+201A SINGLE LOW-9 QUOTATION MARK */
   0x2018,  /* 5 */  /*              U+2018 LEFT SINGLE QUOTATION MARK  (not in TLG spec) */
   0x00AB,  /* 6 */  /* LANG_GREEK:
                        LANG_COPTIC: U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK */
   0x02BB,  /* 7 */  /* LANG_GREEK:
                        LANG_COPTIC: U+02BB MODIFIER LETTER TURNED COMMA
                                     Alternative - U+2039 SINGLE LEFT-POINTING ANGLE QUOTATION MARK
                     */
   0x201C,  /* 8 */  /*              U+201C LEFT DOUBLE QUOTATION MARK (not implemented) */
   0x0022   /* 9 */  /*              U+0022 QUOTATION MARK (not implemented) */
};

/* Unicode character for a closing quote for styles 0 through 9 */
int quote_close[10] = {
   0x201D,  /* 0 */  /* LANG_LATIN:  U+201D RIGHT DOUBLE QUOTATION MARK */
   0x201E,  /* 1 */  /* LANG_HEBREW: U+201E DOUBLE LOW-9 QUOTATION MARK */
   0x201C,  /* 2 */  /*              U+201C LEFT DOUBLE QUOTATION MARK (not paired in TLG spec) */
   0x2019,  /* 3 */  /* LANG_LATIN:  U+2019 RIGHT SINGLE QUOTATION MARK */
   /* 0x02BC   3 */  /* LANG_LATIN:  U+02BC Alternative - MODIFIER LETTER APOSTROPHE */
   0x201A,  /* 4 */  /* LANG_HEBREW: U+201A SINGLE LOW-9 QUOTATION MARK */
   0x201B,  /* 5 */  /*              U+201B SINGLE HIGH-REVERSED-9 QUOTATION MARK (not paired in TLG spec) */
   0x00BB,  /* 6 */  /* LANG_GREEK:
                        LANG_COPTIC: U+00BB RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK */
   0x02BC,  /* 7 */  /* LANG_GREEK:
                        LANG_COPTIC: U+02BC MODIFIER LETTER APOSTROPHE
                                     Alternative - U+203A SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
                     */
   0x201E,  /* 8 */  /*              U+201E DOUBLE LOW-9 QUOTATION MARK (not implemented) */
   0x0022   /* 9 */  /*              U+0022 QUOTATION MARK (not implemented) */
};


/*
   Table to convert an ASCII letter into a capital Unicode Greek letter.
   Middle Sigma, Final Sigma, and Lunate Sigma are handled specially elsewhere.
*/
uint32_t ascii2greek_capital[128] = {
/*   0/8    1/9    2/A    3/B    4/C    5/D    6/E    7/F   */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x00..0x07 */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x08..0x0F */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x10..0x17 */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x18..0x1F */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x20..0x27 */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x28..0x2F */
     '0',   '1',   '2',   '3',   '4',   '5',   '6',   '7',  /* 0x30..0x37 0..7 */
     '8',   '9', 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x38..0x3F 8..? */
   0x000, 0x391, 0x392, 0x39E, 0x394, 0x395, 0x3A6, 0x393,  /* 0x40..0x47 @..G */
   0x397, 0x399, 0x3A2, 0x39A, 0x39B, 0x39C, 0x39D, 0x39F,  /* 0x48..0x4F H..O */
   0x3A0, 0x398, 0x3A1, 0x3A3, 0x3A4, 0x3A5, 0x3F9, 0x3A9,  /* 0x50..0x57 P..W */
   0x3A7, 0x3A8, 0x396, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x58..0x5F X.._ */
   0x000, 0x391, 0x392, 0x39E, 0x394, 0x395, 0x3A6, 0x393,  /* 0x60..0x67 `..g */
   0x397, 0x399, 0x3A2, 0x39A, 0x39B, 0x39C, 0x39D, 0x39F,  /* 0x68..0x6F h..o */
   0x3A0, 0x398, 0x3A1, 0x3A3, 0x3A4, 0x3A5, 0x3DD, 0x3A9,  /* 0x70..0x77 p..w */
   0x3A7, 0x3A8, 0x396, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x78..0x7F x..<DEL> */
/*   0/8    1/9    2/A    3/B    4/C    5/D    6/E    7/F   */
};

/*
   Table to convert an ASCII letter into a small Unicode Greek letter.
   Middle Sigma, Final Sigma, and Lunate Sigma are handled specially elsewhere.
*/
uint32_t ascii2greek_small[128] = {
/*   0/8    1/9    2/A    3/B    4/C    5/D    6/E    7/F   */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x00..0x07 */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x08..0x0F */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x10..0x17 */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x18..0x1F */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x20..0x27 */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x28..0x2F */
     '0',   '1',   '2',   '3',   '4',   '5',   '6',   '7',  /* 0x30..0x37 0..7 */
     '8',   '9', 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x38..0x3F 8..? */
   0x000, 0x3B1, 0x3B2, 0x3BE, 0x3B4, 0x3B5, 0x3C6, 0x3B3,  /* 0x40..0x47 @..G */
   0x3B7, 0x3B9, 0x3C2, 0x3BA, 0x3BB, 0x3BC, 0x3BD, 0x3BF,  /* 0x48..0x4F H..O */
   0x3C0, 0x3B8, 0x3C1, 0x3C3, 0x3C4, 0x3C5, 0x3DD, 0x3C9,  /* 0x50..0x57 P..W */
   0x3C7, 0x3C8, 0x3B6, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x58..0x5F X.._ */
   0x000, 0x3B1, 0x3B2, 0x3BE, 0x3B4, 0x3B5, 0x3C6, 0x3B3,  /* 0x60..0x67 `..g */
   0x3B7, 0x3B9, 0x3C2, 0x3BA, 0x3BB, 0x3BC, 0x3BD, 0x3BF,  /* 0x68..0x6F h..o */
   0x3C0, 0x3B8, 0x3C1, 0x3C3, 0x3C4, 0x3C5, 0x3DD, 0x3C9,  /* 0x70..0x77 p..w */
   0x3C7, 0x3C8, 0x3B6, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x78..0x7F x..<DEL> */
/*   0/8    1/9    2/A    3/B    4/C    5/D    6/E    7/F   */
};

/*
   Table to convert an ASCII letter into a Coptic Unicode letter.

   This table encodes letters that were preceded by a '*'.  If the Latin letter
   was not preceded by a '*', add 1 to get the Unicode code point.
*/
uint32_t ascii2coptic[128] = {
/*   0/8     1/9     2/A     3/B     4/C     5/D     6/E     7/F    */
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,  /* 0x00..0x07 */
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,  /* 0x08..0x0F */
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,  /* 0x10..0x17 */
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,  /* 0x18..0x1F */
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,  /* 0x20..0x27 */
   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,  /* 0x28..0x2F */
      '0',    '1',    '2',    '3',    '4',    '5',    '6',    '7',  /* 0x30..0x37 0..7 */
      '8',    '9', 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,  /* 0x38..0x3F 8..? */
   0x0000, 0x2C80, 0x2C82, 0x2C9C, 0x2C86, 0x2C88, 0x2CAA, 0x2C84,  /* 0x40..0x47 @..G */
   0x2C8E, 0x2C92, 0x0,    0x2C94, 0x2C96, 0x2C98, 0x2C9A, 0x2C9E,  /* 0x48..0x4F H..O */
   0x2CA0, 0x2C90, 0x2CA2, 0x2CA4, 0x2CA6, 0x2CA8, 0x2C8A, 0x2CB0,  /* 0x50..0x57 P..W */
   0x2CAC, 0x0,    0x2C8C, 0x0,    0x0,    0x0,    0x0,    0x0,     /* 0x58..0x5F X.._ */
   0x0,    0x0,    0x0,    0x0,    0x0,    0x0,    0x03E4, 0x03EC,  /* 0x60..0x67 `..g */
   0x03E8, 0x0,    0x03EA, 0x03E6, 0x0,    0x0,    0x0,    0x0,     /* 0x68..0x6F h..o */
   0x0,    0x0,    0x0,    0x03E2, 0x03EE, 0x0,    0x0,    0x0,     /* 0x70..0x77 p..w */
   0x0,    0x0,    0x0,    0x0,    0x0,    0x0,    0x0,    0x0,     /* 0x78..0x7F x..<DEL> */
/*   0/8     1/9     2/A     3/B     4/C     5/D     6/E     7/F    */
};

/*
   Table to convert an ASCII letter into a Hebrew Unicode letter.
*/
uint32_t ascii2hebrew[128] = {
/*   0/8    1/9    2/A    3/B    4/C    5/D    6/E    7/F   */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x00..0x07 */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x08..0x0F */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x10..0x17 */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x18..0x1F */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x20..0x27 */
   0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x28..0x2F */
     '0',   '1',   '2',   '3',   '4',   '5',   '6',   '7',  /* 0x30..0x37 0..7 */
     '8',   '9', 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,  /* 0x38..0x3F 8..? */
   0x0,   0x5D0, 0x0,   0x0,   0x0,   0x0,   0x0,   0x0,    /* 0x40..0x47 @..G */
   0x5D7, 0x0,   0x0,   0x0,   0x0,   0x0,   0x0,   0x0,    /* 0x48..0x4F H..O */
   0x0,   0x5D8, 0x0,   0x5E1, 0x5E6, 0x0,   0x0,   0x0,    /* 0x50..0x57 P..W */
   0x0,   0x0,   0x0,   0x0,   0x0,   0x0,   0x0,   0x0,    /* 0x58..0x5F X.._ */
   0x0,   0x5E2, 0x5D1, 0x0,   0x5D3, 0x0,   0x0,   0x5D2,  /* 0x60..0x67 `..g */
   0x5D4, 0x0,   0x0,   0x5DB, 0x5DC, 0x5DE, 0x5E0, 0x0,    /* 0x68..0x6F h..o */
   0x5E4, 0x5E7, 0x5E8, 0x5E9, 0x5EA, 0x0,   0x5D5, 0x0,    /* 0x70..0x77 p..w */
   0x0,   0x5D9, 0x5D6, 0x0,   0x0,   0x0,   0x0,   0x0,    /* 0x78..0x7F x..<DEL> */
/*   0/8    1/9    2/A    3/B    4/C    5/D    6/E    7/F   */
};


void print_ascii   (char *);    /* print a string that's inside '{'...'}' pair     */
void print_unicode (char *);    /* print a Unicode code point in the form "\uXXXX" */
void print_quote   (char *);    /* print open or close quoation mark styles        */
void print_utf8    (uint32_t);  /* Print a Unicode code point in UTF-8             */
void print_capital (char *);    /* Print Greek, Hebrew, or Coptic capital letter   */
void print_small   (char *);    /* Print Greek, Hebrew, or Coptic small letter     */
void print_pattern (char *, uint32_t);  /* Print yytext in Latin mode or print a Unicode code point in UTF-8 */
/*
   Print a letter in one of four language modes:

        Latin, Greek, Coptic, and Hebrew, respectively.

   Currently this is only needed to handle 'S' and 's'
   because of Greek context-dependent middle and final sigma.
*/
void print_letter  (uint32_t, uint32_t, uint32_t, uint32_t);

//LATIN_GREEK	&[^\$&0-9]*\$([1-4]?[0-9])?
//{LATIN_GREEK}	{  /* Latin short text on one line enclosed within '&' and '$' */
//                  int i, j;  /* loop variables */
//		  lang_type = LANG_LATIN;
//                  singleq_style = 3; /* single quote style */
//                  doubleq_style = 0; /* double quote style */
//                  /* Find start of enclosed string after '&' possible with trailing digits */
//                  for (i = 1; isdigit (yytext [i]); i++);
//		  /* Find '$' that returns to Greek mode, possibly with trailing digits */
//                  for (j = strlen (yytext) - 1; yytext[j] != '$'; j--);
//		  yytext[j] = '\0';  /* Stop output just before the mark to return to Greek mode */
//		  fprintf (yyout, "%s", &yytext[i]);
//		  lang_type = LANG_GREEK;
//                  singleq_style = 7; /* single quote style */
//                  doubleq_style = 6; /* double quote style */
//		}
%}

%option noyywrap

ESCAPE		\{[^\{\}]*\}
QUOTE		(\"|`|')
DECIMAL_DIGIT	[0-9]
SELECT_LATIN	&([1-4]?[0-9])?
SELECT_GREEK	(\$70|\$([1-4]?[0-9])?)
SELECT_COPTIC	(\$50|&100)
SELECT_DEMOTIC	 \$51
SELECT_HEBREW	(\$53|&300)
GREEK_ACCENT	[\(\)\\\/=\+\?\|]

%%
{ESCAPE}	{ /*
		      Print escape-delimited string of ASCII and/or
                      special Unicode symbols of the form "\ux...x"
		   */
		   yytext [strlen (yytext) - 1] = '\0';
		   /* fprintf (yyout, "%s", &yytext[1]); */
		   print_ascii (&yytext[1]);
		}
{QUOTE}		print_quote (yytext); /* print open or close quoation mark according to language mode */
{DECIMAL_DIGIT} fputc (yytext[0], yyout);  /* 0 through 9 are the same in all scripts */
{SELECT_LATIN}	{ /* Latin text extends to end of line */
                  int i;  /* loop variable */
		  lang_type = LANG_LATIN;  /* continues after this character */
                  singleq_style = 3; /* single quote style */
                  doubleq_style = 0; /* double quote style */
                  /* Find start of enclosed string after '&' possible with trailing digits */
                  for (i = 1; isdigit (yytext [i]); i++);
		  fprintf (yyout, "%s", &yytext[i]);
		}
{SELECT_GREEK}	{
		  lang_type = LANG_GREEK;
                  singleq_style = 7; /* single quote style */
                  doubleq_style = 6; /* double quote style */
		}
{SELECT_DEMOTIC} {
		  lang_type = LANG_GREEK;
                  singleq_style = 7; /* single quote style */
                  doubleq_style = 6; /* double quote style */
		 }
{SELECT_COPTIC}	{
		 lang_type = LANG_COPTIC;
                 singleq_style = 7; /* single quote style */
                 doubleq_style = 6; /* double quote style */
		}
{SELECT_HEBREW}	{
		 lang_type = LANG_HEBREW;
                 singleq_style = 4; /* single quote style */
                 doubleq_style = 1; /* double quote style */
		}
\!		print_utf8 ('!');     /* EXCLAMATION MARK (not in Beta Code spec, but preserve it) */
\.		print_utf8 ('.');     /* FULL STOP                                */
,		print_utf8 (',');     /* COMMA                                    */
:		print_letter (':', 0x00B7, 0x00B7, ':'); /* Latin, Greek, Coptic, Hebrew; U+00B7 is MIDDLE DOT */
;		print_utf8   (';');     /* Unicode prefers this over U+037E, GREEK QUESTION MARK */
\-		print_letter ('-', 0x2010, 0x2010, '-'); /* Latin, Greek, Coptic, Hebrew */
_		print_letter ('_', 0x2014, 0x2014,0x2014); /* EM DASH */
#		print_letter ('#', 0x0374, 0x0374, '#');  /* GREEK NUMERAL SIGN; can also be U+02B9 MODIFIER LETTER PRIME */
\)		print_letter (')', 0x0313, 0x0313, ')');  /* COMBINING COMMA ABOVE */
\(		print_letter ('(', 0x0314, 0x0314, '(');  /* COMBINING REVERSED COMMA ABOVE             */
\/		print_letter ('/', 0x0301, 0x0301, '/');  /* COMBINING ACUTE ACCENT                     */
=		print_letter ('=', 0x0342, 0x0301, '=');  /* COMBINING GREEK PERISPOMENI                */
\\		print_letter ('\\',0x0300, 0x0300, '\\'); /* COMBINING GRAVE ACCENT                     */
\+		print_letter ('+', 0x0308, 0x0308, '+');  /* COMBINING DIAERESIS                        */
\|		print_letter ('|', 0x0345, 0x0345, '|');  /* COMBINING GREEK YPOGEGRAMMENI              */
\?		print_letter ('?', 0x0323, '?',    '?');  /* COMBINING DOT BELOW                        */
\<		print_letter ('<', 0x2039, 0x2039, '<');  /* SINGLE LEFT-POINTING ANGLE QUOTATION MARK  */
\>		print_letter ('>', 0x203A, 0x203A, '>');  /* SINGLE RIGHT-POINTING ANGLE QUOTATION MARK */
\*[A-Za-za]	print_capital (yytext); /* Print Greek, Latin, or Coptic capital letter         */
[kmnpT][12]	print_small   (yytext); /* Special cases for Hebrew letters                     */
[A-Za-za]	print_small   (yytext); /* Print Greek, Latin, Coptic, or Hebrew small letter   */
\*\/[Aa]	print_pattern (yytext, 0x0386);  /* GREEK CAPITAL LETTER ALPHA WITH TONOS    */
\*\/[Ee]	print_pattern (yytext, 0x0388);  /* GREEK CAPITAL LETTER EPSILON WITH TONOS  */
\*\/[Hh]	print_pattern (yytext, 0x0389);  /* GREEK CAPITAL LETTER ETA WITH TONOS      */
\*\/[Ii]	print_pattern (yytext, 0x038A);  /* GREEK CAPITAL LETTER IOTA WITH TONOS     */
\*\/[Oo]	print_pattern (yytext, 0x038C);  /* GREEK CAPITAL LETTER OMICRON WITH TONOS  */
\*\/[Uu]	print_pattern (yytext, 0x038E);  /* GREEK CAPITAL LETTER UPSILON WITH TONOS  */
\*\/[Ww]	print_pattern (yytext, 0x038F);  /* GREEK CAPITAL LETTER OMEGA WITH TONOS    */
[Ii](\+\/|\/\+)	print_pattern (yytext, 0x0390);  /* GREEK SMALL LETTER IOTA WITH DIALYTIKA AND TONOS */
\*\+[I]		print_pattern (yytext, 0x03AA);  /* GREEK CAPITAL LETTER IOTA WITH DIALYTIKA */
\*\+[i]		print_pattern (yytext, 0x03AA);  /* GREEK CAPITAL LETTER IOTA WITH DIALYTIKA */
\*\+[Uu]	print_pattern (yytext, 0x03AB);  /* GREEK CAPITAL LETTER UPSILON WITH DIALYTIKA */
[Aa]\/		print_pattern (yytext, 0x03AC);  /* GREEK SMALL LETTER ALPHA WITH TONOS      */
[Ee]\/		print_pattern (yytext, 0x03AD);  /* GREEK SMALL LETTER EPSILON WITH TONOS    */
[Hh]\/		print_pattern (yytext, 0x03AE);  /* GREEK SMALL LETTER ETA WITH TONOS        */
[Ii]\/		print_pattern (yytext, 0x03AF);  /* GREEK SMALL LETTER IOTA WITH TONOS       */
[Uu](\+\/|\/\+)	print_pattern (yytext, 0x03B0);  /* GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND TONOS */
([Ss]2|[Jj])	print_pattern (yytext, 0x03C2);  /* GREEK SMALL LETTER FINAL SIGMA           */
S/[^[:alnum:]]	{  /* "s" at end of word --> final sigma if Greek, otherwise just 's' */
		   print_letter ('s',0x03C2,0x2CA5,0x05E1); /* Latin, Greek, Coptic, Hebrew */
		}
s/[^[:alnum:]]	{  /* "s" at end of word --> final sigma if Greek, otherwise just 's' */
		   print_letter ('s',0x03C2,0x03E3,0x05E9); /* Latin, Greek, Coptic, Hebrew */
		}
[Ss]1?		print_pattern (yytext, 0x03C3);  /* GREEK SMALL LETTER SIGMA                 */
[I]\+		{
		   if (lang_type == LANG_GREEK)
		      print_pattern (yytext, 0x03CA);  /* GREEK SMALL LETTER IOTA WITH DIALYTIKA   */
		   else if (lang_type == LANG_LATIN)
		      fprintf (yyout, "I+");
		   else
		      fprintf (yyout, "{I+}");
		}
[i]\+		{
		   if (lang_type == LANG_GREEK)
		      print_pattern (yytext, 0x03CA);  /* GREEK SMALL LETTER IOTA WITH DIALYTIKA   */
		   else if (lang_type == LANG_LATIN)
		      fprintf (yyout, "i+");
		   else
		      fprintf (yyout, "{i+}");
		}
[U]\+		{
		   if (lang_type == LANG_GREEK)
		      print_pattern (yytext, 0x03CB);  /* GREEK SMALL LETTER UPSILON WITH DIALYTIKA   */
		   else if (lang_type == LANG_LATIN)  /* Most likely a "U+xxxx" Unicode code point */
		      fprintf (yyout, "U+");
		   else
		      fprintf (yyout, "{U+}");
		}
[u]\+		{
		   if (lang_type == LANG_GREEK)
		      print_pattern (yytext, 0x03CB);  /* GREEK SMALL LETTER UPSILON WITH DIALYTIKA   */
		   else if (lang_type == LANG_LATIN)
		      fprintf (yyout, "u+");
		   else
		      fprintf (yyout, "{u+}");
		}
[Oo]\/		print_pattern (yytext, 0x03CC);  /* GREEK SMALL LETTER OMICRON WITH TONOS    */
[Uu]\/		print_pattern (yytext, 0x03CD);  /* GREEK SMALL LETTER UPSILON WITH TONOS    */
[Ww]\/		print_pattern (yytext, 0x03CE);  /* GREEK SMALL LETTER OMEGA WITH TONOS      */
[Ss]3		print_pattern (yytext, 0x03F2);  /* GREEK LUNATE SIGMA SYMBOL                */
\*[Ss]3		print_pattern (yytext, 0x03F9);  /* GREEK CAPITAL LUNATE SIGMA SYMBOL        */
[A-Za-z]\\	print_small   (yytext);/* Disambiguation between Greek and Coptic */
\*\\[A-Za-z]	print_capital (yytext);/* Disambiguation between Greek and Coptic */
[Aa]\)		print_pattern (yytext, 0x1F00);  /* GREEK SMALL LETTER ALPHA WITH PSILI      */
[Aa]\(		print_pattern (yytext, 0x1F01);  /* GREEK SMALL LETTER ALPHA WITH DASIA      */
[Aa]\)\\	print_pattern (yytext, 0x1F02);  /* GREEK SMALL LETTER ALPHA WITH PSILI AND VARIA */
[Aa]\(\\	print_pattern (yytext, 0x1F03);  /* GREEK SMALL LETTER ALPHA WITH DASIA AND VARIA */
[Aa]\)\/	print_pattern (yytext, 0x1F04);  /* GREEK SMALL LETTER ALPHA WITH PSILI AND OXIA */
[Aa]\(\/	print_pattern (yytext, 0x1F05);  /* GREEK SMALL LETTER ALPHA WITH DASIA AND OXIA */
[Aa]\)=		print_pattern (yytext, 0x1F06);  /* GREEK SMALL LETTER ALPHA WITH PSILI AND PERISPOMENI */
[Aa]\(=		print_pattern (yytext, 0x1F07);  /* GREEK SMALL LETTER ALPHA WITH DASIA AND PERISPOMENI */
\*\)[Aa]	print_pattern (yytext, 0x1F08);  /* GREEK CAPITAL LETTER ALPHA WITH PSILI    */
\*\([Aa]	print_pattern (yytext, 0x1F09);  /* GREEK CAPITAL LETTER ALPHA WITH DASIA    */
\*\)\\[Aa]	print_pattern (yytext, 0x1F0A);  /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND VARIA */
\*\(\\[Aa]	print_pattern (yytext, 0x1F0B);  /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND VARIA */
\*\)\/[Aa]	print_pattern (yytext, 0x1F0C);  /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND OXIA */
\*\(\/[Aa]	print_pattern (yytext, 0x1F0D);  /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND OXIA */
\*\)=[Aa]	print_pattern (yytext, 0x1F0E);  /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND PERISPOMENI */
\*\(=[Aa]	print_pattern (yytext, 0x1F0F);  /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND PERISPOMENI */
[Ee]\)		print_pattern (yytext, 0x1F10);  /* GREEK SMALL LETTER EPSILON WITH PSILI    */
[Ee]\(		print_pattern (yytext, 0x1F11);  /* GREEK SMALL LETTER EPSILON WITH DASIA    */
[Ee]\)\\	print_pattern (yytext, 0x1F12);  /* GREEK SMALL LETTER EPSILON WITH PSILI AND VARIA */
[Ee]\(\\	print_pattern (yytext, 0x1F13);  /* GREEK SMALL LETTER EPSILON WITH DASIA AND VARIA */
[Ee]\)\/	print_pattern (yytext, 0x1F14);  /* GREEK SMALL LETTER EPSILON WITH PSILI AND OXIA */
[Ee]\(\/	print_pattern (yytext, 0x1F15);  /* GREEK SMALL LETTER EPSILON WITH DASIA AND OXIA */
\*\)[Ee]	print_pattern (yytext, 0x1F18);  /* GREEK CAPITAL LETTER EPSILON WITH PSILI  */
\*\([Ee]	print_pattern (yytext, 0x1F19);  /* GREEK CAPITAL LETTER EPSILON WITH DASIA  */
\*\)\\[Ee]	print_pattern (yytext, 0x1F1A);  /* GREEK CAPITAL LETTER EPSILON WITH PSILI AND VARIA */
\*\(\\[Ee]	print_pattern (yytext, 0x1F1B);  /* GREEK CAPITAL LETTER EPSILON WITH DASIA AND VARIA */
\*\)\/[Ee]	print_pattern (yytext, 0x1F1C);  /* GREEK CAPITAL LETTER EPSILON WITH PSILI AND OXIA */
\*\(\/[Ee]	print_pattern (yytext, 0x1F1D);  /* GREEK CAPITAL LETTER EPSILON WITH DASIA AND OXIA */
[Hh]\)		print_pattern (yytext, 0x1F20);  /* GREEK SMALL LETTER ETA WITH PSILI        */
[Hh]\(		print_pattern (yytext, 0x1F21);  /* GREEK SMALL LETTER ETA WITH DASIA        */
[Hh]\)\\	print_pattern (yytext, 0x1F22);  /* GREEK SMALL LETTER ETA WITH PSILI AND VARIA */
[Hh]\(\\	print_pattern (yytext, 0x1F23);  /* GREEK SMALL LETTER ETA WITH DASIA AND VARIA */
[Hh]\)\/	print_pattern (yytext, 0x1F24);  /* GREEK SMALL LETTER ETA WITH PSILI AND OXIA */
[Hh]\(\/	print_pattern (yytext, 0x1F25);  /* GREEK SMALL LETTER ETA WITH DASIA AND OXIA */
[Hh]\)=		print_pattern (yytext, 0x1F26);  /* GREEK SMALL LETTER ETA WITH PSILI AND PERISPOMENI */
[Hh]\(=		print_pattern (yytext, 0x1F27);  /* GREEK SMALL LETTER ETA WITH DASIA AND PERISPOMENI */
\*\)[Hh]	print_pattern (yytext, 0x1F28);  /* GREEK CAPITAL LETTER ETA WITH PSILI      */
\*\([Hh]	print_pattern (yytext, 0x1F29);  /* GREEK CAPITAL LETTER ETA WITH DASIA      */
\*\)\\[Hh]	print_pattern (yytext, 0x1F2A);  /* GREEK CAPITAL LETTER ETA WITH PSILI AND VARIA */
\*\(\\[Hh]	print_pattern (yytext, 0x1F2B);  /* GREEK CAPITAL LETTER ETA WITH DASIA AND VARIA */
\*\)\/[Hh]	print_pattern (yytext, 0x1F2C);  /* GREEK CAPITAL LETTER ETA WITH PSILI AND OXIA */
\*\(\/[Hh]	print_pattern (yytext, 0x1F2D);  /* GREEK CAPITAL LETTER ETA WITH DASIA AND OXIA */
\*\)=[Hh]	print_pattern (yytext, 0x1F2E);  /* GREEK CAPITAL LETTER ETA WITH PSILI AND PERISPOMENI */
\*\(=[Hh]	print_pattern (yytext, 0x1F2F);  /* GREEK CAPITAL LETTER ETA WITH DASIA AND PERISPOMENI */
[Ii]\)		print_pattern (yytext, 0x1F30);  /* GREEK SMALL LETTER IOTA WITH PSILI       */
[Ii]\(		print_pattern (yytext, 0x1F31);  /* GREEK SMALL LETTER IOTA WITH DASIA       */
[Ii]\)\\	print_pattern (yytext, 0x1F32);  /* GREEK SMALL LETTER IOTA WITH PSILI AND VARIA */
[Ii]\(\\	print_pattern (yytext, 0x1F33);  /* GREEK SMALL LETTER IOTA WITH DASIA AND VARIA */
[Ii]\)\/	print_pattern (yytext, 0x1F34);  /* GREEK SMALL LETTER IOTA WITH PSILI AND OXIA */
[Ii]\(\/	print_pattern (yytext, 0x1F35);  /* GREEK SMALL LETTER IOTA WITH DASIA AND OXIA */
[Ii]\)=		print_pattern (yytext, 0x1F36);  /* GREEK SMALL LETTER IOTA WITH PSILI AND PERISPOMENI */
[Ii]\(=		print_pattern (yytext, 0x1F37);  /* GREEK SMALL LETTER IOTA WITH DASIA AND PERISPOMENI */
\*\)[Ii]	print_pattern (yytext, 0x1F38);  /* GREEK CAPITAL LETTER IOTA WITH PSILI     */
\*\([Ii]	print_pattern (yytext, 0x1F39);  /* GREEK CAPITAL LETTER IOTA WITH DASIA     */
\*\)\\[Ii]	print_pattern (yytext, 0x1F3A);  /* GREEK CAPITAL LETTER IOTA WITH PSILI AND VARIA */
\*\(\\[Ii]	print_pattern (yytext, 0x1F3B);  /* GREEK CAPITAL LETTER IOTA WITH DASIA AND VARIA */
\*\)\/[Ii]	print_pattern (yytext, 0x1F3C);  /* GREEK CAPITAL LETTER IOTA WITH PSILI AND OXIA */
\*\(\/[Ii]	print_pattern (yytext, 0x1F3D);  /* GREEK CAPITAL LETTER IOTA WITH DASIA AND OXIA */
\*\)=[Ii]	print_pattern (yytext, 0x1F3E);  /* GREEK CAPITAL LETTER IOTA WITH PSILI AND PERISPOMENI */
\*\(=[Ii]	print_pattern (yytext, 0x1F3F);  /* GREEK CAPITAL LETTER IOTA WITH DASIA AND PERISPOMENI */
[Oo]\)		print_pattern (yytext, 0x1F40);  /* GREEK SMALL LETTER OMICRON WITH PSILI    */
[Oo]\(		print_pattern (yytext, 0x1F41);  /* GREEK SMALL LETTER OMICRON WITH DASIA    */
[Oo]\)\\	print_pattern (yytext, 0x1F42);  /* GREEK SMALL LETTER OMICRON WITH PSILI AND VARIA */
[Oo]\(\\	print_pattern (yytext, 0x1F43);  /* GREEK SMALL LETTER OMICRON WITH DASIA AND VARIA */
[Oo]\)\/	print_pattern (yytext, 0x1F44);  /* GREEK SMALL LETTER OMICRON WITH PSILI AND OXIA */
[Oo]\(\/	print_pattern (yytext, 0x1F45);  /* GREEK SMALL LETTER OMICRON WITH DASIA AND OXIA */
\*\)[Oo]	print_pattern (yytext, 0x1F48);  /* GREEK CAPITAL LETTER OMICRON WITH PSILI  */
\*\([Oo]	print_pattern (yytext, 0x1F49);  /* GREEK CAPITAL LETTER OMICRON WITH DASIA  */
\*\)\\[Oo]	print_pattern (yytext, 0x1F4A);  /* GREEK CAPITAL LETTER OMICRON WITH PSILI AND VARIA */
\*\(\\[Oo]	print_pattern (yytext, 0x1F4B);  /* GREEK CAPITAL LETTER OMICRON WITH DASIA AND VARIA */
\*\)\/[Oo]	print_pattern (yytext, 0x1F4C);  /* GREEK CAPITAL LETTER OMICRON WITH PSILI AND OXIA */
\*\(\/[Oo]	print_pattern (yytext, 0x1F4D);  /* GREEK CAPITAL LETTER OMICRON WITH DASIA AND OXIA */
[Uu]\)		print_pattern (yytext, 0x1F50);  /* GREEK SMALL LETTER UPSILON WITH PSILI    */
[Uu]\(		print_pattern (yytext, 0x1F51);  /* GREEK SMALL LETTER UPSILON WITH DASIA    */
[Uu]\)\\	print_pattern (yytext, 0x1F52);  /* GREEK SMALL LETTER UPSILON WITH PSILI AND VARIA */
[Uu]\(\\	print_pattern (yytext, 0x1F53);  /* GREEK SMALL LETTER UPSILON WITH DASIA AND VARIA */
[Uu]\)\/	print_pattern (yytext, 0x1F54);  /* GREEK SMALL LETTER UPSILON WITH PSILI AND OXIA */
[Uu]\(\/	print_pattern (yytext, 0x1F55);  /* GREEK SMALL LETTER UPSILON WITH DASIA AND OXIA */
[Uu]\)=		print_pattern (yytext, 0x1F56);  /* GREEK SMALL LETTER UPSILON WITH PSILI AND PERISPOMENI */
[Uu]\(=		print_pattern (yytext, 0x1F57);  /* GREEK SMALL LETTER UPSILON WITH DASIA AND PERISPOMENI */
\*\([Uu]	print_pattern (yytext, 0x1F59);  /* GREEK CAPITAL LETTER UPSILON WITH DASIA  */
\*\(\\[Uu]	print_pattern (yytext, 0x1F5B);  /* GREEK CAPITAL LETTER UPSILON WITH DASIA AND VARIA */
\*\(\/[Uu]	print_pattern (yytext, 0x1F5D);  /* GREEK CAPITAL LETTER UPSILON WITH DASIA AND OXIA */
\*\(=[Uu]	print_pattern (yytext, 0x1F5F);  /* GREEK CAPITAL LETTER UPSILON WITH DASIA AND PERISPOMENI */
[Ww]\)		print_pattern (yytext, 0x1F60);  /* GREEK SMALL LETTER OMEGA WITH PSILI      */
[Ww]\(		print_pattern (yytext, 0x1F61);  /* GREEK SMALL LETTER OMEGA WITH DASIA      */
[Ww]\)\\	print_pattern (yytext, 0x1F62);  /* GREEK SMALL LETTER OMEGA WITH PSILI AND VARIA */
[Ww]\(\\	print_pattern (yytext, 0x1F63);  /* GREEK SMALL LETTER OMEGA WITH DASIA AND VARIA */
[Ww]\)\/	print_pattern (yytext, 0x1F64);  /* GREEK SMALL LETTER OMEGA WITH PSILI AND OXIA */
[Ww]\(\/	print_pattern (yytext, 0x1F65);  /* GREEK SMALL LETTER OMEGA WITH DASIA AND OXIA */
[Ww]\)=		print_pattern (yytext, 0x1F66);  /* GREEK SMALL LETTER OMEGA WITH PSILI AND PERISPOMENI */
[Ww]\(=		print_pattern (yytext, 0x1F67);  /* GREEK SMALL LETTER OMEGA WITH DASIA AND PERISPOMENI */
\*\)[Ww]	print_pattern (yytext, 0x1F68);  /* GREEK CAPITAL LETTER OMEGA WITH PSILI    */
\*\([Ww]	print_pattern (yytext, 0x1F69);  /* GREEK CAPITAL LETTER OMEGA WITH DASIA    */
\*\)\\[Ww]	print_pattern (yytext, 0x1F6A);  /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND VARIA */
\*\(\\[Ww]	print_pattern (yytext, 0x1F6B);  /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND VARIA */
\*\)\/[Ww]	print_pattern (yytext, 0x1F6C);  /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND OXIA */
\*\(\/[Ww]	print_pattern (yytext, 0x1F6D);  /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND OXIA */
\*\)=[Ww]	print_pattern (yytext, 0x1F6E);  /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND PERISPOMENI */
\*\(=[Ww]	print_pattern (yytext, 0x1F6F);  /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND PERISPOMENI */
[Aa]\)\|	print_pattern (yytext, 0x1F80);  /* GREEK SMALL LETTER ALPHA WITH PSILI AND YPOGEGRAMMENI */
[Aa]\(\|	print_pattern (yytext, 0x1F81);  /* GREEK SMALL LETTER ALPHA WITH DASIA AND YPOGEGRAMMENI */
[Aa]\)\\\|	print_pattern (yytext, 0x1F82);  /* GREEK SMALL LETTER ALPHA WITH PSILI AND VARIA AND YPOGEGRAMMENI */
[Aa]\(\\\|	print_pattern (yytext, 0x1F83);  /* GREEK SMALL LETTER ALPHA WITH DASIA AND VARIA AND YPOGEGRAMMENI */
[Aa]\)\/\|	print_pattern (yytext, 0x1F84);  /* GREEK SMALL LETTER ALPHA WITH PSILI AND OXIA AND YPOGEGRAMMENI */
[Aa]\(\/\|	print_pattern (yytext, 0x1F85);  /* GREEK SMALL LETTER ALPHA WITH DASIA AND OXIA AND YPOGEGRAMMENI */
[Aa]\)=\|	print_pattern (yytext, 0x1F86);  /* GREEK SMALL LETTER ALPHA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI */
[Aa]\(=\|	print_pattern (yytext, 0x1F87);  /* GREEK SMALL LETTER ALPHA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI */
\*\)[Aa]\|	print_pattern (yytext, 0x1F88);  /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND PROSGEGRAMMENI */
\*\([Aa]\|	print_pattern (yytext, 0x1F89);  /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND PROSGEGRAMMENI */
\*\)\\[Aa]\|	print_pattern (yytext, 0x1F8A);  /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND VARIA AND PROSGEGRAMMENI */
\*\(\\[Aa]\|	print_pattern (yytext, 0x1F8B);  /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND VARIA AND PROSGEGRAMMENI */
\*\)\/[Aa]\|	print_pattern (yytext, 0x1F8C);  /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND OXIA AND PROSGEGRAMMENI */
\*\(\/[Aa]\|	print_pattern (yytext, 0x1F8D);  /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND OXIA AND PROSGEGRAMMENI */
\*\)=[Aa]\|	print_pattern (yytext, 0x1F8E);  /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI */
\*\(=[Aa]\|	print_pattern (yytext, 0x1F8F);  /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI */
[Hh]\)\|	print_pattern (yytext, 0x1F90);  /* GREEK SMALL LETTER ETA WITH PSILI AND YPOGEGRAMMENI */
[Hh]\(\|	print_pattern (yytext, 0x1F91);  /* GREEK SMALL LETTER ETA WITH DASIA AND YPOGEGRAMMENI */
[Hh]\)\\\|	print_pattern (yytext, 0x1F92);  /* GREEK SMALL LETTER ETA WITH PSILI AND VARIA AND YPOGEGRAMMENI */
[Hh]\(\\\|	print_pattern (yytext, 0x1F93);  /* GREEK SMALL LETTER ETA WITH DASIA AND VARIA AND YPOGEGRAMMENI */
[Hh]\)\/\|	print_pattern (yytext, 0x1F94);  /* GREEK SMALL LETTER ETA WITH PSILI AND OXIA AND YPOGEGRAMMENI */
[Hh]\(\/\|	print_pattern (yytext, 0x1F95);  /* GREEK SMALL LETTER ETA WITH DASIA AND OXIA AND YPOGEGRAMMENI */
[Hh]\)=\|	print_pattern (yytext, 0x1F96);  /* GREEK SMALL LETTER ETA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI */
[Hh]\(=\|	print_pattern (yytext, 0x1F97);  /* GREEK SMALL LETTER ETA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI */
\*\)[Hh]\|	print_pattern (yytext, 0x1F98);  /* GREEK CAPITAL LETTER ETA WITH PSILI AND PROSGEGRAMMENI */
\*\([Hh]\|	print_pattern (yytext, 0x1F99);  /* GREEK CAPITAL LETTER ETA WITH DASIA AND PROSGEGRAMMENI */
\*\)\\[Hh]\|	print_pattern (yytext, 0x1F9A);  /* GREEK CAPITAL LETTER ETA WITH PSILI AND VARIA AND PROSGEGRAMMENI */
\*\(\\[Hh]\|	print_pattern (yytext, 0x1F9B);  /* GREEK CAPITAL LETTER ETA WITH DASIA AND VARIA AND PROSGEGRAMMENI */
\*\)\/[Hh]\|	print_pattern (yytext, 0x1F9C);  /* GREEK CAPITAL LETTER ETA WITH PSILI AND OXIA AND PROSGEGRAMMENI */
\*\(\/[Hh]\|	print_pattern (yytext, 0x1F9D);  /* GREEK CAPITAL LETTER ETA WITH DASIA AND OXIA AND PROSGEGRAMMENI */
\*\)=[Hh]\|	print_pattern (yytext, 0x1F9E);  /* GREEK CAPITAL LETTER ETA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI */
\*\(=[Hh]\|	print_pattern (yytext, 0x1F9F);  /* GREEK CAPITAL LETTER ETA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI */
[Ww]\)\|	print_pattern (yytext, 0x1FA0);  /* GREEK SMALL LETTER OMEGA WITH PSILI AND YPOGEGRAMMENI */
[Ww]\(\|	print_pattern (yytext, 0x1FA1);  /* GREEK SMALL LETTER OMEGA WITH DASIA AND YPOGEGRAMMENI */
[Ww]\)\\\|	print_pattern (yytext, 0x1FA2);  /* GREEK SMALL LETTER OMEGA WITH PSILI AND VARIA AND YPOGEGRAMMENI */
[Ww]\(\\\|	print_pattern (yytext, 0x1FA3);  /* GREEK SMALL LETTER OMEGA WITH DASIA AND VARIA AND YPOGEGRAMMENI */
[Ww]\)\/\|	print_pattern (yytext, 0x1FA4);  /* GREEK SMALL LETTER OMEGA WITH PSILI AND OXIA AND YPOGEGRAMMENI */
[Ww]\(\/\|	print_pattern (yytext, 0x1FA5);  /* GREEK SMALL LETTER OMEGA WITH DASIA AND OXIA AND YPOGEGRAMMENI */
[Ww]\)=\|	print_pattern (yytext, 0x1FA6);  /* GREEK SMALL LETTER OMEGA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI */
[Ww]\(=\|	print_pattern (yytext, 0x1FA7);  /* GREEK SMALL LETTER OMEGA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI */
\*\)[Ww]\|	print_pattern (yytext, 0x1FA8);  /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND PROSGEGRAMMENI */
\*\([Ww]\|	print_pattern (yytext, 0x1FA9);  /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND PROSGEGRAMMENI */
\*\)\\[Ww]\|	print_pattern (yytext, 0x1FAA);  /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND VARIA AND PROSGEGRAMMENI */
\*\(\\[Ww]\|	print_pattern (yytext, 0x1FAB);  /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND VARIA AND PROSGEGRAMMENI */
\*\)\/[Ww]\|	print_pattern (yytext, 0x1FAC);  /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND OXIA AND PROSGEGRAMMENI */
\*\(\/[Ww]\|	print_pattern (yytext, 0x1FAD);  /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND OXIA AND PROSGEGRAMMENI */
\*\)=[Ww]\|	print_pattern (yytext, 0x1FAE);  /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI */
\*\(=[Ww]\|	print_pattern (yytext, 0x1FAF);  /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI */
[Aa]'		print_pattern (yytext, 0x1FB0);  /* GREEK SMALL LETTER ALPHA WITH VRACHY     */
[Aa]&		print_pattern (yytext, 0x1FB1);  /* GREEK SMALL LETTER ALPHA WITH MACRON     */
[Aa]\\\|	print_pattern (yytext, 0x1FB2);  /* GREEK SMALL LETTER ALPHA WITH VARIA AND YPOGEGRAMMENI */
[Aa]\|		print_pattern (yytext, 0x1FB3);  /* GREEK SMALL LETTER ALPHA WITH YPOGEGRAMMENI */
[Aa]\/\|	print_pattern (yytext, 0x1FB4);  /* GREEK SMALL LETTER ALPHA WITH OXIA AND YPOGEGRAMMENI */
[Aa]=		print_pattern (yytext, 0x1FB6);  /* GREEK SMALL LETTER ALPHA WITH PERISPOMENI */
[Aa]=\|		print_pattern (yytext, 0x1FB7);  /* GREEK SMALL LETTER ALPHA WITH PERISPOMENI AND YPOGEGRAMMENI */
\*'[Aa]		print_pattern (yytext, 0x1FB8);  /* GREEK CAPITAL LETTER ALPHA WITH VRACHY   */
\*&[Aa]		print_pattern (yytext, 0x1FB9);  /* GREEK CAPITAL LETTER ALPHA WITH MACRON   */
\*[Aa]\|	print_pattern (yytext, 0x1FBC);  /* GREEK CAPITAL LETTER ALPHA WITH PROSGEGRAMMENI */
(\+=|=\+)	print_pattern (yytext, 0x1FC1);  /* GREEK DIALYTIKA AND PERISPOMENI          */
[Hh]\\\|	print_pattern (yytext, 0x1FC2);  /* GREEK SMALL LETTER ETA WITH VARIA AND YPOGEGRAMMENI */
[Hh]\|		print_pattern (yytext, 0x1FC3);  /* GREEK SMALL LETTER ETA WITH YPOGEGRAMMENI */
[Hh]\/\|	print_pattern (yytext, 0x1FC4);  /* GREEK SMALL LETTER ETA WITH OXIA AND YPOGEGRAMMENI */
[Hh]=		print_pattern (yytext, 0x1FC6);  /* GREEK SMALL LETTER ETA WITH PERISPOMENI  */
[Hh]=\|		print_pattern (yytext, 0x1FC7);  /* GREEK SMALL LETTER ETA WITH PERISPOMENI AND YPOGEGRAMMENI */
\*[Hh]\|	print_pattern (yytext, 0x1FCC);  /* GREEK CAPITAL LETTER ETA WITH PROSGEGRAMMENI */
\)\\		print_pattern (yytext, 0x1FCD);  /* GREEK PSILI AND VARIA                    */
\)\/		print_pattern (yytext, 0x1FCE);  /* GREEK PSILI AND OXIA                     */
\)=		print_pattern (yytext, 0x1FCF);  /* GREEK PSILI AND PERISPOMENI              */
[Ii]'		print_pattern (yytext, 0x1FD0);  /* GREEK SMALL LETTER IOTA WITH VRACHY      */
[Ii]&		print_pattern (yytext, 0x1FD1);  /* GREEK SMALL LETTER IOTA WITH MACRON      */
[Ii](\\\+|\+\\)	print_pattern (yytext, 0x1FD2);  /* GREEK SMALL LETTER IOTA WITH DIALYTIKA AND VARIA */
[Ii]=		print_pattern (yytext, 0x1FD6);  /* GREEK SMALL LETTER IOTA WITH PERISPOMENI */
[Ii](=\+|\+=)	print_pattern (yytext, 0x1FD7);  /* GREEK SMALL LETTER IOTA WITH DIALYTIKA AND PERISPOMENI */
\*'[Ii]		print_pattern (yytext, 0x1FD8);  /* GREEK CAPITAL LETTER IOTA WITH VRACHY    */
\*&[Ii]		print_pattern (yytext, 0x1FD9);  /* GREEK CAPITAL LETTER IOTA WITH MACRON    */
\(\\		print_pattern (yytext, 0x1FDD);  /* GREEK DASIA AND VARIA                    */
\(\/		print_pattern (yytext, 0x1FDE);  /* GREEK DASIA AND OXIA                     */
\(=		print_pattern (yytext, 0x1FDF);  /* GREEK DASIA AND PERISPOMENI              */
[Uu]'		print_pattern (yytext, 0x1FE0);  /* GREEK SMALL LETTER UPSILON WITH VRACHY   */
[Uu]&		print_pattern (yytext, 0x1FE1);  /* GREEK SMALL LETTER UPSILON WITH MACRON   */
[Uu](\\\+|\+\\)	print_pattern (yytext, 0x1FE2);  /* GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND VARIA */
[Rr]\)		print_pattern (yytext, 0x1FE4);  /* GREEK SMALL LETTER RHO WITH PSILI        */
[Rr]\(		print_pattern (yytext, 0x1FE5);  /* GREEK SMALL LETTER RHO WITH DASIA        */
[Uu]=		print_pattern (yytext, 0x1FE6);  /* GREEK SMALL LETTER UPSILON WITH PERISPOMENI */
[Uu](=\+|\+=)	print_pattern (yytext, 0x1FE7);  /* GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND PERISPOMENI */
\*'[Uu]		print_pattern (yytext, 0x1FE8);  /* GREEK CAPITAL LETTER UPSILON WITH VRACHY */
\*&[Uu]		print_pattern (yytext, 0x1FE9);  /* GREEK CAPITAL LETTER UPSILON WITH MACRON */
\*\([Rr]	print_pattern (yytext, 0x1FEC);  /* GREEK CAPITAL LETTER RHO WITH DASIA      */
(\\\+|\+\\)	print_pattern (yytext, 0x1FED);  /* GREEK DIALYTIKA AND VARIA                */
(\/\+|\+\/)	print_pattern (yytext, 0x1FEE);  /* GREEK DIALYTIKA AND OXIA                 */
[Ww]\\\|	print_pattern (yytext, 0x1FF2);  /* GREEK SMALL LETTER OMEGA WITH VARIA AND YPOGEGRAMMENI */
[Ww]\|		print_pattern (yytext, 0x1FF3);  /* GREEK SMALL LETTER OMEGA WITH YPOGEGRAMMENI */
[Ww]\/\|	print_pattern (yytext, 0x1FF4);  /* GREEK SMALL LETTER OMEGA WITH OXIA AND YPOGEGRAMMENI */
[Ww]=		print_pattern (yytext, 0x1FF6);  /* GREEK SMALL LETTER OMEGA WITH PERISPOMENI */
[Ww]=\|		print_pattern (yytext, 0x1FF7);  /* GREEK SMALL LETTER OMEGA WITH PERISPOMENI AND YPOGEGRAMMENI */
\*[Ww]\|	print_pattern (yytext, 0x1FFC);  /* GREEK CAPITAL LETTER OMEGA WITH PROSGEGRAMMENI */
%%

int
main (int argc, char *argv[])
{
   int i;            /* loop variable       */
   int exit_status;  /* program exit status */

   void print_help (char *);

   exit_status = EXIT_SUCCESS;
   yyin  = stdin;
   yyout = stdout;

   for (i = 1; i < argc; i++) {
      /*
         Parse options.  If an invalid command line argument
         was given, print a help menu and exit with error status.
      */
      if (argv[i][0] == '-') {
         switch (argv[i][1]) {
                      /* Begin output with Byte Order Mark, U+FFFE */
            case 'b': bom_out = 1;
                      break;
                      /*
                         input file format; file name follows
                         in next parameter, so increment i
                      */
            case 'i': yyin  = fopen (argv[++i], "r");
                      break;
                      /*
                         output file format; file name follows
                         in next parameter, so increment i
                      */
            case 'o': yyout = fopen (argv[++i], "w");
                      break;
                      /* quote mark style for open & close quotes */
            default:  print_help (argv[0]);
                      exit_status = EXIT_FAILURE;
                      break;
         }
      }
      else {
         print_help (argv[0]);
         exit_status = EXIT_FAILURE;
      }
   }

   if (exit_status == EXIT_SUCCESS) {
      if (bom_out != 0) {
         print_utf8 (0xFFFE); /* Unicode Byte Order Mark */
      }

      yylex ();
   }

   exit (exit_status);
}


/*
   Print a help message.  The parameter is the program name,
   taken from argv[0].
*/
void
print_help (char * progname)
{

   fprintf (stderr, "\nUnknown command line parameter.\n\n");
   fprintf (stderr, "Syntax: %s [-b] [-i input_file] [-o output_file]\n\n",
            progname);
   fprintf (stderr, "    -b: begin output with UTF-8 Byte Order Mark\n\n");
   fprintf (stderr, "    -i: specify input file name\n\n");
   fprintf (stderr, "    -o: specify output file name\n\n");

   return;
}


/*
   Print a pattern that was read as ASCII if in Latin mode.
   Otherwise, print the UTF-8 code point.
*/
void
print_pattern (char *intext, uint32_t codept)
{

   void print_ascii (char *);
   void print_utf8  (uint32_t);

   if (lang_type == LANG_LATIN)
      print_ascii (intext);
   else
      print_utf8 (codept);

   return;
}


/*
   Print an ASCII sequence that appeared inside braces, '{'...'}'.
*/
void
print_ascii (char *intext)
{
   int i, j, k;  /* loop variables */
   char unicode_string[7]; /* up to six hexadecimal digits, null-terminated */

   for (i = 0; intext[i] != '\0'; i++) {
      /*
         Scan for a backslash, looking for an escape sequence.
         At present, the only recognized escape sequence is "\u"
         to represent a Unicode hexadecimal code point of the
         form "\uX...X", where "X...X" is a string of one to six
         hexadecimal digits that specify a valid Unicode code point.
      */
      for (j = i;
           intext[j] != '\0' && intext[j] != '\\';
           j++);

      if (intext [j] == '\0') {  /* this is probably the most frequent case */
         fprintf (yyout, "%s", &intext [i]);
         i = j-1;  /* so the outer i loop will terminate */
      }
      /*
         Found a backslash, so look for a following 'u'.
      */
      else if (intext [j+1] == 'u') {
         /* print the string up to but not including the backslash */
         intext[j] = '\0';
         fprintf (yyout, "%s", &intext[i]);
         i = j + 2; /* i points to first digit in Unicode code point */
         unicode_string [0] = '\0';  /* start building the Unicode code point string */
         /*
            scan to end of hexadecimal digits, up to six digits
         */
         for (k = 0;
              k < 6 &&  /* allow up to six hexadecimal digits */
              (isdigit (intext [i]) ||
               (intext [i] >= 'A' && intext [i] <= 'F') ||
               (intext [i] >= 'a' && intext [i] <= 'f'));
              k++) {

            unicode_string [k]     = intext[i];
            unicode_string [k + 1] = '\0';  /* make sure string stays null-terminated */
            i++;
         }
         print_unicode (unicode_string);
         /* intext [i] points to the remainder of the input string */
         i--;  /* it will be incremented again next i loop iteration */
      }  /* intext [j+1] == 'u' */
      /*
         Otherwise, this was not a recognized '\' sequence,
         so print string up to the backslash and keep going.
      */
      else {
         intext [j] = '\0';  /* replace '\\' with null to print up to this location */
         fprintf (yyout, "%s\\", &intext [i]);
         i = j;  /* keep scanning intext[i] until the end is reached */
      }
   }

   return;
}


/*
   Print a Unicode code point in the form "X...X",
   where "X...X" is a string of one to six hexadeimcal
   digits that describe a valid Unicode code point.
*/
void
print_unicode (char *intext)
{
   int i;  /* loop variable */
   uint32_t this_digit;   /* current ASCII hexadecimal digit being converted */
   uint32_t codept;  /* the Unicode code point to output */

   void print_utf8 (uint32_t);

   codept = 0;
   for (i = 0; intext[i] != '\0'; i++) {
      codept <<= 4;  /* shift one hexadecimal digit to the left */
      this_digit = intext[i];
      if (this_digit >= 'a')
         this_digit = this_digit - 'a' + 10;
      else if (this_digit >= 'A')
         this_digit = this_digit - 'A' + 10;
      else
         this_digit -= '0';

      codept |= this_digit;
   }  /* for i */

   print_utf8 (codept);

   return;
}


/*
   Print an open or close quote dependent on language mode.

        intext  character string starting with '"'
                or "`" or "'".
*/
void
print_quote (char *intext)
{

   void print_utf8 (uint32_t);

   /* Double qoute, the most common case */
   if (intext[0] == '"') {
      if (quote_state[doubleq_style] == 0) {  /* print opening quote */
         print_utf8 (quote_open[doubleq_style]);
         quote_state[doubleq_style] = 1;  /* now entering a quote style */
      }
      else {                          /* print closing quote */
         print_utf8 (quote_close[doubleq_style]);
         quote_state[doubleq_style] = 0;  /* now leaving a quote style */
      }
   }
   else { /* open ("`") or close ("'") single quote */
      if (intext[0] == '`') { /* open quote */
         if (singleq_style == 0)      /* Latin  */
            print_utf8 (0x02BB);
         else if (singleq_style == 4) /* Hebrew */
            print_utf8 (0x201A);
         else                         /* Greek, Coptic, or Demotic */
            print_utf8 (0x02BB);
      }
      else { /* close quote, "'" */
         if (singleq_style == 0)      /* Latin  */
            print_utf8 (0x02BC);
         else if (singleq_style == 4) /* Hebrew */
            print_utf8 (0x2018);
         else                         /* Greek, Coptic, or Demotic */
            print_utf8 (0x02BC);
      }
   }

   return;
}


/*
   Print Greek, Latin, Coptic, or Hebrew capital letter.

   This is passed yytext, so the first character in the
   input string is a '*'; skip over it for indexing.
*/
void
print_capital (char *intext)
{
   int test_char;  /* character to test */

   test_char = intext[1] & 0x7F;

   switch (lang_type) {
      case LANG_GREEK:
           /* First check for Greek varia (grave accent) on vowel */
           if (intext[2] == '\\') { /* intext[2] should either be '\\' or '\0' */
              test_char = tolower (test_char);
              switch (test_char) {
                 case 'a':
                      print_utf8 (0x1FBA);  /* GREEK CAPITAL LETTER ALPHA WITH VARIA   */
                      break;
                 case 'e':
                      print_utf8 (0x1FC8);  /* GREEK CAPITAL LETTER EPSILON WITH VARIA */
                      break;
                 case 'h':
                      print_utf8 (0x1FCA);  /* GREEK CAPITAL LETTER ETA WITH VARIA     */
                      break;
                 case 'i':
                      print_utf8 (0x1FDA);  /* GREEK CAPITAL LETTER IOTA WITH VARIA    */
                      break;
                 case 'o':
                      print_utf8 (0x1FEA);  /* GREEK CAPITAL LETTER UPSILON WITH VARIA */
                      break;
                 case 'u':
                      print_utf8 (0x1FF8);  /* GREEK CAPITAL LETTER OMICRON WITH VARIA */
                      break;
                 case 'w':
                      print_utf8 (0x1FFA);  /* GREEK CAPITAL LETTER OMEGA WITH VARIA   */
                      break;
                 default:
                      fprintf (yyout, "%s", intext);  /* unexpected combination */
                      break;
              }
           }
           else {
              /*
                 ascii2greek_cap contains Unicode encodings for
                 capital Greek letters.
              */
              print_utf8 (ascii2greek_capital[test_char]);
           }
           break;
      case LANG_COPTIC:
           print_utf8 (ascii2coptic[test_char]);
           /* Now check for Coptic jinkim (grave accent) on letter */
           if (intext[2] == '\\')
              print_utf8 (0x0300);  /* COMBINING GRAVE ACCENT */
           break;
      case LANG_HEBREW: /* Hebrew Beta Code doesn't use '*'; we should not reach this point */
           break;
      case LANG_LATIN:
           fprintf (yyout, "%s", intext);
           break;
      default:
           break;
   }

   return;
}


/*
   Print Greek, Latin, Coptic, or Hebrew small letter.
*/
void
print_small (char *intext)
{
   int test_char;   /* character to test */
   int letter_form; /* =1 if letter is the final form, 2 if not; for Hebrew */

   test_char = intext[0] & 0x7F;

   switch (lang_type) {
      case LANG_GREEK:
           /* First check for varia (grave accent) on vowel */
           if (intext[1] == '\\') {  /* intext[1] should either be '\\' or '\0' */
              test_char = tolower (test_char);
              switch (test_char) {
                 case 'a':
                      print_utf8 (0x1F70);  /* GREEK SMALL LETTER ALPHA WITH VARIA   */
                      break;
                 case 'e':
                      print_utf8 (0x1F72);  /* GREEK SMALL LETTER EPSILON WITH VARIA */
                      break;
                 case 'h':
                      print_utf8 (0x1F74);  /* GREEK SMALL LETTER ETA WITH VARIA     */
                      break;
                 case 'i':
                      print_utf8 (0x1F76);  /* GREEK SMALL LETTER IOTA WITH VARIA    */
                      break;
                 case 'o':
                      print_utf8 (0x1F78);  /* GREEK SMALL LETTER OMICRON WITH VARIA */
                      break;
                 case 'u':
                      print_utf8 (0x1F7A);  /* GREEK SMALL LETTER UPSILON WITH VARIA */
                      break;
                 case 'w':
                      print_utf8 (0x1F7C);  /* GREEK SMALL LETTER OMEGA WITH VARIA   */
                      break;
                 default:
                      fprintf (yyout, "%s", intext);  /* unexpected combination */
                      break;
              }
           }
           else {
              print_utf8 (ascii2greek_small[test_char]);
           }
           break;
      case LANG_COPTIC:
           /*
              Small Coptic letters are one code point above
              the corresponding capital letter contained in
              the ascii2coptic array, so add one for print_utf8.
           */
           print_utf8 (ascii2coptic[test_char] + 1);
           if (intext[1] == '\\')
              print_utf8 (0x0300);  /* COMBINING GRAVE ACCENT */
           break;
      case LANG_HEBREW:
           test_char = intext[0];
           /*
              If this is a letter that has middle and final forms,
              look at next character for the digit '1' (final form)
              or '2' (middle form).
           */
           if (test_char == 'k' || test_char == 'm' || test_char == 'n' ||
               test_char == 'p' || test_char == 'T') {
              letter_form = yytext[1];
              if (letter_form == '2') {
                 switch (test_char) {
                    case 'k':
                         print_utf8 (0x5DA); /* HEBREW LETTER FINAL KAF   */
                         break;
                    case 'm':
                         print_utf8 (0x5DD); /* HEBREW LETTER FINAL MEM   */
                         break;
                    case 'n':
                         print_utf8 (0x5DF); /* HEBREW LETTER FINAL NUN   */
                         break;
                    case 'p':
                         print_utf8 (0x5E3); /* HEBREW LETTER FINAL PE    */
                         break;
                    case 'T':
                         print_utf8 (0x5E5); /* HEBREW LETTER FINAL TSADI */
                         break;
                    default:
                         fprintf (yyout, "%s", intext);
                         break;
                 }
              }
              else {  /* a '2' was not the next character, so not final form */
                 /*
                    Print the middle form of the letter, even if
                    it was not given correctly with a '1' appended.
                 */
                 switch (test_char) {
                    case 'k':
                         print_utf8 (0x5DB); /* HEBREW LETTER KAF   */
                         break;
                    case 'm':
                         print_utf8 (0x5DE); /* HEBREW LETTER MEM   */
                         break;
                    case 'n':
                         print_utf8 (0x5E0); /* HEBREW LETTER NUN   */
                         break;
                    case 'p':
                         print_utf8 (0x5E4); /* HEBREW LETTER PE    */
                         break;
                    case 'T':
                         print_utf8 (0x5E6); /* HEBREW LETTER TSADI */
                         break;
                    default:
                         fprintf (yyout, "%s", intext);
                         break;
                 }
              }
           }
           else {  /* it's a Hebrew letter that only has one form */
              print_utf8 (ascii2hebrew[test_char]);
           }
           break;
      case LANG_LATIN:
           fprintf (yyout, "%s", intext);
           break;
      default:
           break;
   }

   return;
}


/*
   Print one of four letter choices depending on whether the
   language mode is Latin, Greek, Coptic, or Hebrew, respectively.
*/
void
print_letter (uint32_t latin,  uint32_t greek,
              uint32_t coptic, uint32_t hebrew)
{

   switch (lang_type) {
      case LANG_LATIN:
           print_utf8 (latin);
           break;
      case LANG_GREEK:
           print_utf8 (greek);
           break;
      case LANG_COPTIC:
           print_utf8 (coptic);
           break;
      case LANG_HEBREW:
           print_utf8 (hebrew);
           break;
      default:
           print_utf8 (greek);
           break;
   }

   return;
}


/*
   Convert a UTF-32 code point to a UTF-8 string.
*/
void
print_utf8 (uint32_t codept)
{
   int i;              /* loop variable                              */
   int bin_length;     /* number of binary digits, for forming UTF-8 */
   int byte_length;    /* numberof bytes of UTF-8                    */
   char utf8_bytes[4]; /* temporary array of UTF-8 output bytes      */

   int bin_digits (uint32_t);

   byte_length = 0;

   /*
      If within valid 0x2039Unicode range of U+0000..U+10FFFF, proceed
   */
   if (codept <= 0x10FFFF) {
      bin_length = bin_digits (codept);
      if (bin_length < 8) {        /* U+0000..U+007F */
         byte_length = 1;
         utf8_bytes [0] = codept;
      }
      else if (bin_length < 12) {  /* U+0080..U+07FF */
         byte_length = 2;
         utf8_bytes [0] = 0xC0 | ((codept >>  6) & 0x1F);
         utf8_bytes [1] = 0x80 | ( codept        & 0x3F);
      }
      else if (bin_length < 17) {  /* U+0800..U+FFFF */
         byte_length = 3;
         utf8_bytes [0] = 0xE0 | ((codept >> 12) & 0x0F);
         utf8_bytes [1] = 0x80 | ((codept >>  6) & 0x3F);
         utf8_bytes [2] = 0x80 | ( codept        & 0x3F);
      }
      else if (bin_length < 22) {  /* U+010000..U+10FFFF */
         byte_length = 4;
         utf8_bytes [0] = 0xF0 | ((codept >> 18) & 0x07);
         utf8_bytes [1] = 0x80 | ((codept >> 12) & 0x3F);
         utf8_bytes [2] = 0x80 | ((codept >>  6) & 0x3F);
         utf8_bytes [3] = 0x80 | ( codept        & 0x3F);
      }
      else {
         fprintf (stderr,
                  "Internal error forming UTF-8 in print_utf8() for U+%04X\n",
                  codept);
      }

      for (i = 0; i < byte_length; i++) putchar (utf8_bytes [i]);
   }
   else {
      fprintf (stderr,
               "print_utf8() called with illegal Unicode code point U+%06X\n",
               codept);
   }

   return;
}


/*
   Return the number of significant binary digits in an unsigned number.
*/
int
bin_digits (uint32_t itest)
{
   uint32_t i;
   int result;

   i = 0x80000000;  /* mask highest uint32_t bit */
   result = 32;
   while (  (i != 0) && ((itest & i) == 0) ) {
       i >>= 1;
       result--;
   }

   return result;
}

