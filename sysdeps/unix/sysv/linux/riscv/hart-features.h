/* Initialize CPU feature data.  RISC-V version.
   This file is part of the GNU C Library.
   Copyright (C) 2022 Free Software Foundation, Inc.

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

#ifndef _CPU_FEATURES_RISCV_H
#define _CPU_FEATURES_RISCV_H

#define IS_RV32() \
	(GLRO (dl_riscv_hart_features).xlen == 32)

#define IS_RV64() \
	(GLRO (dl_riscv_hart_features).xlen == 64)

#define HAVE_RV(E) \
	(GLRO (dl_riscv_hart_features).have_ ## E == 1)

#define HAVE_CBOM_BLOCKSIZE(n)	\
	(GLRO (dl_riscv_hart_features).cbom_blocksize == n)

#define HAVE_CBOZ_BLOCKSIZE(n)	\
	(GLRO (dl_riscv_hart_features).cboz_blocksize == n)

#define HAVE_FAST_UNALIGNED() \
	(GLRO (dl_riscv_hart_features).fast_unaligned != 0)

struct hart_features
{
  const char* rt_march;
  unsigned xlen;
#define ISA_EXT(e)			\
  unsigned have_##e:1;
#define ISA_EXT_GROUP(g, ...)		\
  unsigned have_##g:1;
#include "isa-extensions.def"

  const char* rt_cbom_blocksize;
  unsigned cbom_blocksize;
  const char* rt_cboz_blocksize;
  unsigned cboz_blocksize;
  const char* rt_fast_unaligned;
  unsigned fast_unaligned;
};

#endif /* _CPU_FEATURES_RISCV_H  */
