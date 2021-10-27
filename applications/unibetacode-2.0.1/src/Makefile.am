## Process this file with automake to produce Makefile.in

bin_PROGRAMS = unibetaprep beta2uni uni2beta
unibetaprep_SOURCES = progsrc/unibetaprep.l
beta2uni_SOURCES = progsrc/beta2uni.l
uni2beta_SOURCES = progsrc/uni2beta.l

EXTRA_DIST = \
	libsrc/ub_beta2greek.h \
	libsrc/ub_beta2coptic.h \
	libsrc/ub_beta2hebrew.h \
	libsrc/ub_greek2beta.h \
	libsrc/ub_coptic2beta.h \
	libsrc/ub_hebrew2beta.h

lib_LIBRARIES = libunibetacode.a

libunibetacode_a_SOURCES = \
	libsrc/ub_utf8.c \
	libsrc/ub_beta2greek.c \
	libsrc/ub_beta2coptic.c \
	libsrc/ub_beta2hebrew.c \
	libsrc/ub_greek2beta.c \
	libsrc/ub_coptic2beta.c \
	libsrc/ub_hebrew2beta.c

