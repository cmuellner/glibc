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

/* Assumptions: rvi_zbb with fast unaligned access.  */
/* Implementation inspired by aarch64/strcmp.S.  */

#define src1		a0
#define result		a0
#define src2		a1
#define off		a3
#define m1		a4
#define align1		a5
#define src3		a6
#define tmp		a7

#define data1		t0
#define data2		t1
#define b1		t0
#define b2		t1
#define data3		t2
#define data1_orcb	t3
#define data3_orcb	t4
#define shift		t5

#if __riscv_xlen == 64
# define REG_L	ld
# define SZREG	8
# define PTRLOG	3
#else
# define REG_L	lw
# define SZREG	4
# define PTRLOG	2
#endif

#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
# error big endian is untested!
# define CZ	ctz
# define SHIFT	srl
# define SHIFT2	sll
#else
# define CZ	ctz
# define SHIFT	sll
# define SHIFT2	srl
#endif

#ifndef STRCMP
# define STRCMP __strcmp_zbb_unaligned
#endif

.option push
.option arch,+zbb

ENTRY_ALIGN (STRCMP, 6)
	/* off...delta from src1 to src2.  */
	sub	off, src2, src1
	li	m1, -1
	andi	tmp, off, SZREG-1
	andi	align1, src1, SZREG-1
	bnez	tmp, L(misaligned8)
	bnez	align1, L(mutual_align)

	.p2align 4
L(loop_aligned):
	REG_L	data1, 0(src1)
	add	tmp, src1, off
	addi	src1, src1, SZREG
	REG_L	data2, 0(tmp)

L(start_realigned):
	orc.b	data1_orcb, data1
	bne	data1_orcb, m1, L(end)
	beq	data1, data2, L(loop_aligned)

L(fast_end):
	/* Words don't match, and no NUL byte in one word.
	   Get bytes in big-endian order and compare as words.  */
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	rev8	data1, data1
	rev8	data2, data2
#endif
	/* Synthesize (data1 >= data2) ? 1 : -1 in a branchless sequence.  */
	sltu	result, data1, data2
	neg	result, result
	ori	result, result, 1
	ret

L(end_orc):
	orc.b	data1_orcb, data1
L(end):
	/* Words don't match or NUL byte in at least one word.
	   data1_orcb holds orc.b value of data1.  */
	xor	tmp, data1, data2
	orc.b	tmp, tmp

	orn	tmp, tmp, data1_orcb
	CZ	shift, tmp

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	rev8	data1, data1
	rev8	data2, data2
#endif
	sll	data1, data1, shift
	sll	data2, data2, shift
	srl	b1, data1, SZREG*8-8
	srl	b2, data2, SZREG*8-8

L(end_singlebyte):
	sub	result, b1, b2
	ret

	.p2align 4
L(mutual_align):
	/* Sources are mutually aligned, but are not currently at an
	   alignment boundary.  Round down the addresses and then mask off
	   the bytes that precede the start point.  */
	andi	src1, src1, -SZREG
	add	tmp, src1, off
	REG_L	data1, 0(src1)
	addi	src1, src1, SZREG
	REG_L	data2, 0(tmp)
	/* Get number of bits to mask.  */
	sll	shift, src2, 3
	/* Bits to mask are now 0, others are 1.  */
	SHIFT	tmp, m1, shift
	/* Or with inverted value -> masked bits become 1.  */
	orn	data1, data1, tmp
	orn	data2, data2, tmp
	j	L(start_realigned)

L(misaligned8):
	/* Skip slow loop if SRC1 is aligned.  */
	beqz	align1, L(src1_aligned)
L(do_misaligned):
	/* Align SRC1 to 8 bytes.  */
	lbu	b1, 0(src1)
	lbu	b2, 0(src2)
	beqz	b1, L(end_singlebyte)
	bne	b1, b2, L(end_singlebyte)
	addi	src1, src1, 1
	addi	src2, src2, 1
	andi	align1, src1, SZREG-1
	bnez	align1, L(do_misaligned)

L(src1_aligned):
	/* SRC1 is aligned. Align SRC2 down and check for NUL there.
	 * If there is no NUL, we may read the next word from SRC2.
	 * If there is a NUL, we must not read a complete word from SRC2
	 * because we might cross a page boundary.  */
	/* Get number of bits to mask (upper bits are ignored by shifts).  */
	sll	shift, src2, 3
	/* src3 := align_down (src2)  */
	andi	src3, src2, -SZREG
	REG_L   data3, 0(src3)
	addi	src3, src3, SZREG

	/* Bits to mask are now 0, others are 1.  */
	SHIFT	tmp, m1, shift
	/* Or with inverted value -> masked bits become 1.  */
	orn	data3_orcb, data3, tmp
	/* Check for NUL in next aligned word.  */
	orc.b	data3_orcb, data3_orcb
	bne	data3_orcb, m1, L(unaligned_nul)

	.p2align 4
L(loop_unaligned):
	/* Read the (aligned) data1 and the unaligned data2.  */
	REG_L	data1, 0(src1)
	addi	src1, src1, SZREG
	REG_L	data2, 0(src2)
	addi	src2, src2, SZREG
	orc.b	data1_orcb, data1
	bne	data1_orcb, m1, L(end)
	bne	data1, data2, L(end)

	/* Read the next aligned-down word.  */
	REG_L	data3, 0(src3)
	addi	src3, src3, SZREG
	orc.b	data3_orcb, data3
	beq	data3_orcb, m1, L(loop_unaligned)

L(unaligned_nul):
	/* src1 points to unread word (only first bytes relevant).
	 * data3 holds next aligned-down word with NUL.
	 * Compare the first bytes of data1 with the last bytes of data3.  */
	REG_L	data1, 0(src1)
	/* Shift NUL bytes into data3 to become data2.  */
	SHIFT2	data2, data3, shift
	bne	data1, data2, L(end_orc)
	li	result, 0
	ret

.option pop

END (STRCMP)
libc_hidden_builtin_def (STRCMP)
