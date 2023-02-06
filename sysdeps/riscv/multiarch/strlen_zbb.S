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

/* Assumptions: rvi_zbb.  */
/* Implementation from the Bitmanip specification.  */

#define src		a0
#define result		a0
#define addr		a1
#define data		a2
#define offset		a3
#define offset_bits	a3
#define valid_bytes	a4
#define m1		a4

#if __riscv_xlen == 64
# define REG_L	ld
# define SZREG	8
#else
# define REG_L	lw
# define SZREG	4
#endif

#define BITSPERBYTELOG 3

#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
# define CZ	clz
# define SHIFT	sll
#else
# define CZ	ctz
# define SHIFT	srl
#endif

#ifndef STRLEN
# define STRLEN __strlen_zbb
#endif

.option push
.option arch,+zbb

ENTRY_ALIGN (STRLEN, 6)
	andi	offset, src, SZREG-1
	andi	addr, src, -SZREG

	li	valid_bytes, SZREG
	sub	valid_bytes, valid_bytes, offset
	slli	offset_bits, offset, BITSPERBYTELOG
	REG_L	data, 0(addr)
	/* Shift the partial/unaligned chunk we loaded to remove the bytes
	 * from before the start of the string, adding NUL bytes at the end. */
	SHIFT	data, data, offset_bits
	orc.b	data, data
	not	data, data
	/* Non-NUL bytes in the string have been expanded to 0x00, while
	 * NUL bytes have become 0xff. Search for the first set bit
	 * (corresponding to a NUL byte in the original chunk). */
	CZ	data, data
	/* The first chunk is special: compare against the number of valid
	 * bytes in this chunk. */
	srli	result, data, 3
	bgtu	valid_bytes, result, L(done)
	addi	offset, addr, SZREG
	li	m1, -1

	/* Our critical loop is 4 instructions and processes data in 4 byte
	 * or 8 byte chunks.  */
	.p2align 2
L(loop):
	REG_L	data, SZREG(addr)
	addi	addr, addr, SZREG
	orc.b	data, data
	beq	data, m1, L(loop)

L(epilogue):
	not	data, data
	CZ	data, data
	sub	offset, addr, offset
	add	result, result, offset
	srli	data, data, 3
	add	result, result, data
L(done):
	ret

.option pop

END (STRLEN)
libc_hidden_builtin_def (STRLEN)
