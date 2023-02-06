/* Multiple versions of strlen. RISC-V version.
   Copyright (C) 2022 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

/* Define multiple versions only for the definition in libc.  */

#if IS_IN (libc)
/* Redefine strlen so that the compiler won't complain about the type
   mismatch with the IFUNC selector in strong_alias, below.  */
# undef strlen
# define strlen __redirect_strlen
# include <string.h>
# include <ldsodefs.h>
# include <sys/auxv.h>
# include <init-arch.h>

extern __typeof (__redirect_strlen) __libc_strlen;
extern __typeof (__redirect_strlen) __strlen_generic attribute_hidden;
extern __typeof (__redirect_strlen) __strlen_zbb attribute_hidden;

libc_ifunc (__libc_strlen,
	    HAVE_RV(zbb)
	     ? __strlen_zbb
	     : __strlen_generic);

# undef strlen
strong_alias (__libc_strlen, strlen);
#else
# include <string/strlen.c>
#endif
