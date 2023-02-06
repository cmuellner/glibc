/* Copyright (C) 2022 Free Software Foundation, Inc.

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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#include <sysdep.h>
#include <sys/asm.h>

.option push
.option arch,+zawrs

ENTRY_ALIGN (__cpu_relax_zawrs, 4)
	wrs.sto
	ret
END (__cpu_relax_zawrs)

.option pop

.option push
.option arch,+zihintpause

ENTRY_ALIGN (__cpu_relax_zihintpause, 4)
	pause
	ret
END (__cpu_relax_zihintpause)

.option pop
