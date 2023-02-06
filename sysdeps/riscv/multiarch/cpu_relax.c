/* CPU strand yielding for busy loops.  RISC-V version.
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

#include <ldsodefs.h>
#include <init-arch.h>

void __cpu_relax (void);
extern void __cpu_relax_zawrs (void);
extern void __cpu_relax_zihintpause (void);

static void
__cpu_relax_generic (void)
{
}

libc_ifunc (__cpu_relax,
	    HAVE_RV(zawrs)
	    ? __cpu_relax_zawrs
	    : HAVE_RV(zihintpause)
	      ? __cpu_relax_zihintpause
	      : __cpu_relax_generic);
