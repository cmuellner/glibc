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

#define src1		a0
#define result		a0
#define src2		a1
#define len		a2
#define data1		a2
#define data2		a3
#define align		a4
#define data1_orcb	t0
#define limit		t1
#define fast_limit      t2
#define m1		t3

#if __riscv_xlen == 64
# define REG_L	ld
# define SZREG	8
# define PTRLOG	3
#else
# define REG_L	lw
# define SZREG	4
# define PTRLOG	2
#endif

#ifndef STRNCMP
# define STRNCMP __strncmp_zbb
#endif

.option push
.option arch,+zbb

ENTRY_ALIGN (STRNCMP, 6)
	beqz	len, L(equal)
	or	align, src1, src2
	and	align, align, SZREG-1
	add	limit, src1, len
	bnez	align, L(simpleloop)
	li	m1, -1

	/* Adjust limit for fast-path.  */
	andi fast_limit, limit, -SZREG

	/* Main loop for aligned string.  */
	.p2align 3
L(loop):
	bge	src1, fast_limit, L(simpleloop)
	REG_L	data1, 0(src1)
	REG_L	data2, 0(src2)
	orc.b	data1_orcb, data1
	bne	data1_orcb, m1, L(foundnull)
	addi	src1, src1, SZREG
	addi	src2, src2, SZREG
	beq	data1, data2, L(loop)

	/* Words don't match, and no null byte in the first
	 * word. Get bytes in big-endian order and compare.  */
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	rev8	data1, data1
	rev8	data2, data2
#endif
	/* Synthesize (data1 >= data2) ? 1 : -1 in a branchless sequence.  */
	sltu	result, data1, data2
	neg	result, result
	ori	result, result, 1
	ret

L(foundnull):
	/* Found a null byte.
	 * If words don't match, fall back to simple loop.  */
	bne	data1, data2, L(simpleloop)

	/* Otherwise, strings are equal.  */
	li	result, 0
	ret

	/* Simple loop for misaligned strings.  */
	.p2align 3
L(simpleloop):
	bge	src1, limit, L(equal)
	lbu	data1, 0(src1)
	addi	src1, src1, 1
	lbu	data2, 0(src2)
	addi	src2, src2, 1
	bne	data1, data2, L(sub)
	bnez	data1, L(simpleloop)

L(sub):
	sub	result, data1, data2
	ret

L(equal):
	li	result, 0
	ret

.option pop

END (STRNCMP)
libc_hidden_builtin_def (STRNCMP)
