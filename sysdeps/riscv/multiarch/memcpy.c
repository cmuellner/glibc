/* Multiple versions of memcpy. RISC-V version.
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
/* Redefine memcpy so that the compiler won't complain about the type
   mismatch with the IFUNC selector in strong_alias, below.  */
# undef memcpy
# define memcpy __redirect_memcpy
# include <string.h>
# include <ldsodefs.h>
# include <sys/auxv.h>
# include <init-arch.h>

extern __typeof (__redirect_memcpy) __libc_memcpy;
extern __typeof (__redirect_memcpy) __memcpy_generic attribute_hidden;

#if __riscv_xlen == 64
extern __typeof (__redirect_memcpy) __memcpy_rv64_unaligned attribute_hidden;

libc_ifunc (__libc_memcpy,
	    (IS_RV64() && HAVE_FAST_UNALIGNED()
	    ? __memcpy_rv64_unaligned
	    : __memcpy_generic));
#else
libc_ifunc (__libc_memcpy, __memcpy_generic);
#endif

# undef memcpy
strong_alias (__libc_memcpy, memcpy);
#else
# include <string/memcpy.c>
#endif
