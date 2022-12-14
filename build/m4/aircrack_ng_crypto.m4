dnl Aircrack-ng
dnl
dnl Copyright (C) 2017,2022 Joseph Benden <joe@benden.us>
dnl
dnl Autotool support was written by: Joseph Benden <joe@benden.us>
dnl
dnl This program is free software; you can redistribute it and/or modify
dnl it under the terms of the GNU General Public License as published by
dnl the Free Software Foundation; either version 2 of the License, or
dnl (at your option) any later version.
dnl
dnl This program is distributed in the hope that it will be useful,
dnl but WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
dnl GNU General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with this program; if not, write to the Free Software
dnl Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
dnl
dnl In addition, as a special exception, the copyright holders give
dnl permission to link the code of portions of this program with the
dnl OpenSSL library under certain conditions as described in each
dnl individual source file, and distribute linked combinations
dnl including the two.
dnl
dnl You must obey the GNU General Public License in all respects
dnl for all of the code used other than OpenSSL.
dnl
dnl If you modify file(s) with this exception, you may extend this
dnl exception to your dnl version of the file(s), but you are not obligated
dnl to do so.
dnl
dnl If you dnl do not wish to do so, delete this exception statement from your
dnl version.
dnl
dnl If you delete this exception statement from all source files in the
dnl program, then also delete it here.

AC_DEFUN([AIRCRACK_NG_CRYPTO],[

AC_ARG_WITH(expensive-tests,
    [AS_HELP_STRING([--without-expensive-tests],
        [disable all the CPU-intensive unit-tests.])])

case "$with_expensive_tests" in
    yes | y | "")
        AX_APPEND_FLAG(-DEXPENSIVE_TESTS, [opt_[]_AC_LANG_ABBREV[]flags])
    ;;
esac

AC_ARG_ENABLE(static-crypto,
    AS_HELP_STRING([--enable-static-crypto],
		[Enable statically linked OpenSSL libcrypto.]),
    [static_crypto=$enableval], [static_crypto=no])

if test "x$static_crypto" != "xno"; then
	AC_REQUIRE([AX_EXT_HAVE_STATIC_LIB_DETECT])
	AX_EXT_HAVE_STATIC_LIB(ZLIB, ${DEFAULT_STATIC_LIB_SEARCH_PATHS}, z libz, compress)
	AX_EXT_HAVE_STATIC_LIB(OPENSSL, ${DEFAULT_STATIC_LIB_SEARCH_PATHS}, crypto libcrypto, HMAC, -lz -ldl)
else
	AX_CHECK_OPENSSL([OPENSSL_FOUND=yes],[OPENSSL_FOUND=no])

	AX_LIB_GCRYPT
fi

CRYPTO_CFLAGS=
CRYPTO_INCLUDES=
CRYPTO_LIBS=
CRYPTO_LDFLAGS=
CRYPTO_TYPE=

AC_MSG_CHECKING([for OpenSSL or libgcrypt])
if test x"$GCRYPT_LIBS" != x; then
    AC_MSG_RESULT([libgcrypt])
    CRYPTO_CFLAGS="$GCRYPT_CFLAGS -DUSE_GCRYPT"
    CRYPTO_INCLUDES=""
    CRYPTO_LIBS="$GCRYPT_LIBS"
    CRYPTO_LDFLAGS=""
    CRYPTO_TYPE=libgcrypt
elif test "$OPENSSL_FOUND" = yes; then
    AC_MSG_RESULT([OpenSSL])
    CRYPTO_INCLUDES="$OPENSSL_INCLUDES"
    CRYPTO_LIBS="$OPENSSL_LIBS"
    CRYPTO_LDFLAGS="$OPENSSL_LDFLAGS"
    CRYPTO_TYPE=openssl

    AC_CHECK_HEADERS([openssl/cmac.h], [
        AC_DEFINE([HAVE_OPENSSL_CMAC_H], [1], [Define if you have openssl/cmac.h header present.])
        HAVE_CMAC=yes
    ], [HAVE_CMAC=no])

    OPENSSL_WITH_AES=
    OPENSSL_WITH_ARCFOUR=
    OPENSSL_WITH_CMAC=
    OPENSSL_WITH_MD5=
    OPENSSL_WITH_SHA1=
    OPENSSL_WITH_SHA256=
    save_LIBS="$LIBS"
    save_LDFLAGS="$LDFLAGS"
    save_CPPFLAGS="$CPPFLAGS"
    LDFLAGS="$LDFLAGS $OPENSSL_LDFLAGS"
    LIBS="$OPENSSL_LIBS $LIBS"
    CPPFLAGS="$OPENSSL_INCLUDES $CPPFLAGS -Werror"
    AC_MSG_CHECKING([whether OpenSSL supports MD5])
    AC_LINK_IFELSE(
        [AC_LANG_PROGRAM([#include <openssl/evp.h>], [
            EVP_md5();
            ])],
        [
            OPENSSL_WITH_MD5=1
            AC_DEFINE([OPENSSL_WITH_MD5], [1], [Define if your OpenSSL has an MD5 implementation.])
            AC_MSG_RESULT([yes])
        ], [
            AC_MSG_RESULT([no])
        ])
    AC_MSG_CHECKING([whether OpenSSL supports AES])
    AC_LINK_IFELSE(
        [AC_LANG_PROGRAM([#include <openssl/evp.h>], [EVP_aes_128_cbc()])],
        [
            OPENSSL_WITH_AES=1
            AC_DEFINE([OPENSSL_WITH_AES], [1], [Define if your OpenSSL has an AES_128_cbc implementation.])
            AC_MSG_RESULT([yes])
        ], [
            AC_MSG_RESULT([no])
        ])
    AC_MSG_CHECKING([whether OpenSSL supports ARCFOUR])
    AC_LINK_IFELSE(
        [AC_LANG_PROGRAM([
                #include <openssl/rc4.h>
                #include <string.h>
            ], [
#if OPENSSL_VERSION_NUMBER < 0x30000000L
                RC4_KEY ctx;
                memset(&ctx, 0, sizeof(ctx));
#else
# error "no ARCFOUR here!!!"
#endif
            ])],
        [
            OPENSSL_WITH_ARCFOUR=1
            AC_DEFINE([OPENSSL_WITH_ARCFOUR], [1], [Define if your OpenSSL has an ARC4 implementation.])
            AC_MSG_RESULT([yes])
        ], [
            AC_MSG_RESULT([no])
        ])
if test x"$HAVE_CMAC" = xyes; then
    AC_MSG_CHECKING([whether OpenSSL supports CMAC])
    AC_LINK_IFELSE(
        [AC_LANG_PROGRAM([#include <openssl/cmac.h>], [
#if OPENSSL_VERSION_NUMBER >= 0x30000000L
# error "No CMAC here!!!"
#else
            CMAC_CTX_new()
#endif
        ])],
        [
            OPENSSL_WITH_CMAC=1
            AC_DEFINE([OPENSSL_WITH_CMAC], [1], [Define if your OpenSSL has a CMAC implementation.])
            AC_MSG_RESULT([yes])
        ], [
            AC_MSG_RESULT([no])
        ])
fi
    AC_MSG_CHECKING([whether OpenSSL supports SHA-1])
    AC_LINK_IFELSE(
        [AC_LANG_PROGRAM([#include <openssl/evp.h>], [
            EVP_sha1();
            ])],
        [
            OPENSSL_WITH_SHA1=1
            AC_DEFINE([OPENSSL_WITH_SHA1], [1], [Define if your OpenSSL has an SHA-1 implementation.])
            AC_MSG_RESULT([yes])
        ], [
            AC_MSG_RESULT([no])
        ])
    AC_MSG_CHECKING([whether OpenSSL supports SHA-256])
    AC_LINK_IFELSE(
        [AC_LANG_PROGRAM([#include <openssl/evp.h>], [
            EVP_sha256();
            ])],
        [
            OPENSSL_WITH_SHA256=1
            AC_DEFINE([OPENSSL_WITH_SHA256], [1], [Define if your OpenSSL has an SHA-256 implementation.])
            AC_MSG_RESULT([yes])
        ], [
            AC_MSG_RESULT([no])
        ])
    LDFLAGS="$save_LDFLAGS"
    LIBS="$save_LIBS"
    CPPFLAGS="$save_CPPFLAGS"
else
    AC_MSG_ERROR([one of OpenSSL or Gcrypt was not found])
fi

AC_SUBST(CRYPTO_CFLAGS)
AC_SUBST(CRYPTO_INCLUDES)
AC_SUBST(CRYPTO_LIBS)
AC_SUBST(CRYPTO_LDFLAGS)

AM_CONDITIONAL([LIBGCRYPT], [test "$CRYPTO_TYPE" = libgcrypt])
AM_CONDITIONAL([GCRYPT_WITH_AES], [test x"${GCRYPT_WITH_AES}" != x])
AM_CONDITIONAL([GCRYPT_WITH_ARCFOUR], [test x"${GCRYPT_WITH_ARCFOUR}" != x])
AM_CONDITIONAL([GCRYPT_WITH_CMAC], [test x"${GCRYPT_WITH_CMAC_AES}" != x])
AM_CONDITIONAL([GCRYPT_WITH_MD5], [test x"${GCRYPT_WITH_MD5}" != x])
AM_CONDITIONAL([GCRYPT_WITH_SHA1], [test x"${GCRYPT_WITH_SHA1}" != x])
AM_CONDITIONAL([GCRYPT_WITH_SHA256], [test x"${GCRYPT_WITH_SHA256}" != x])
AM_CONDITIONAL([OPENSSL_WITH_AES], [test x"${OPENSSL_WITH_AES}" != x])
AM_CONDITIONAL([OPENSSL_WITH_ARCFOUR], [test x"${OPENSSL_WITH_ARCFOUR}" != x])
AM_CONDITIONAL([OPENSSL_WITH_CMAC], [test x"${OPENSSL_WITH_CMAC}" != x])
AM_CONDITIONAL([OPENSSL_WITH_MD5], [test x"${OPENSSL_WITH_MD5}" != x])
AM_CONDITIONAL([OPENSSL_WITH_SHA1], [test x"${OPENSSL_WITH_SHA1}" != x])
AM_CONDITIONAL([OPENSSL_WITH_SHA256], [test x"${OPENSSL_WITH_SHA256}" != x])
AM_CONDITIONAL([STATIC_CRYPTO], [test "$static_crypto" != no])
])
