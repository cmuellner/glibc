/* Enumerate available IFUNC implementations of a function.  RISC-V version.
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

#include <assert.h>
#include <string.h>
#include <wchar.h>
#include <ldsodefs.h>
#include <ifunc-impl-list.h>
#include <init-arch.h>
#include <stdio.h>

/* Maximum number of IFUNC implementations.  */
#define MAX_IFUNC	7

size_t
__libc_ifunc_impl_list (const char *name, struct libc_ifunc_impl *array,
			size_t max)
{
  assert (max >= MAX_IFUNC);

  size_t i = 0;

  IFUNC_IMPL (i, name, memcpy,
#if __riscv_xlen == 64
	      IFUNC_IMPL_ADD (array, i, memcpy, 1, __memcpy_rv64_unaligned)
#endif
	      IFUNC_IMPL_ADD (array, i, memcpy, 1, __memcpy_generic))

  IFUNC_IMPL (i, name, memmove,
#if __riscv_xlen == 64
	      IFUNC_IMPL_ADD (array, i, memmove, 1, __memmove_rv64_unaligned)
#endif
	      IFUNC_IMPL_ADD (array, i, memmove, 1, __memmove_generic))

  IFUNC_IMPL (i, name, memset,
#if __riscv_xlen == 64
	      IFUNC_IMPL_ADD (array, i, memset, 1, __memset_rv64_unaligned_cboz64)
	      IFUNC_IMPL_ADD (array, i, memset, 1, __memset_rv64_unaligned)
#endif
	      IFUNC_IMPL_ADD (array, i, memset, 1, __memset_generic))

  IFUNC_IMPL (i, name, strlen,
	      IFUNC_IMPL_ADD (array, i, strlen, 1, __strlen_zbb)
	      IFUNC_IMPL_ADD (array, i, strlen, 1, __strlen_generic))

  IFUNC_IMPL (i, name, strcmp,
	      IFUNC_IMPL_ADD (array, i, strcmp, 1, __strcmp_zbb_unaligned)
	      IFUNC_IMPL_ADD (array, i, strcmp, 1, __strcmp_zbb)
	      IFUNC_IMPL_ADD (array, i, strcmp, 1, __strcmp_generic))

  return i;
}
