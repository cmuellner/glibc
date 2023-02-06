/* Multiple versions of strcmp. RISC-V version.
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
/* Redefine strcmp so that the compiler won't complain about the type
   mismatch with the IFUNC selector in strong_alias, below.  */
# undef strcmp
# define strcmp __redirect_strcmp
# include <string.h>
# include <ldsodefs.h>
# include <sys/auxv.h>
# include <init-arch.h>

extern __typeof (__redirect_strcmp) __libc_strcmp;
extern __typeof (__redirect_strcmp) __strcmp_generic attribute_hidden;

libc_ifunc (__libc_strcmp, __strcmp_generic);

# undef strcmp
strong_alias (__libc_strcmp, strcmp);
#else
# include <string/strcmp.c>
#endif
