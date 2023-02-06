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

#if __riscv_xlen == 64

#include <sysdep.h>
#include <sys/asm.h>

#define dst	a0
#define src	a1
#define count	a2
#define srcend	a3
#define dstend	a4
#define tmp1	a5
#define dst2	t6

#define A_l	a6
#define A_h	a7
#define B_l	t0
#define B_h	t1
#define C_l	t2
#define C_h	t3
#define D_l	t4
#define D_h	t5
#define E_l	tmp1
#define E_h	count
#define F_l	dst2
#define F_h	srcend

#ifndef MEMCPY
# define MEMCPY __memcpy_rv64_unaligned
#endif

#ifndef MEMMOVE
# define MEMMOVE __memmove_rv64_unaligned
#endif

#ifndef COPY97_128
# define COPY97_128 1
#endif

/* Assumptions: rv64i, unaligned accesses.  */

/* memcpy/memmove is implemented by unrolling copy loops.
   We have two strategies:
   1) copy from front/start to back/end ("forward")
   2) copy from back/end to front/start ("backward")
   In case of memcpy(), the strategy does not matter for correctness.
   For memmove() and overlapping buffers we need to use the following strategy:
     if dst < src && src-dst < count -> copy from front to back
     if src < dst && dst-src < count -> copy from back to front  */

ENTRY_ALIGN (MEMCPY, 6)
	/* Calculate the end position.  */
	add	srcend, src, count
	add	dstend, dst, count

	/* Decide how to process.  */
	li	tmp1, 96
	bgtu	count, tmp1, L(copy_long_forward)
	li	tmp1, 32
	bgtu	count, tmp1, L(copy33_96)
	li	tmp1, 16
	bleu	count, tmp1, L(copy0_16)

	/* Copy 17-32 bytes.  */
	ld	A_l, 0(src)
	ld	A_h, 8(src)
	ld	B_l, -16(srcend)
	ld	B_h, -8(srcend)
	sd	A_l, 0(dst)
	sd	A_h, 8(dst)
	sd	B_l, -16(dstend)
	sd	B_h, -8(dstend)
	ret

L(copy0_16):
	li	tmp1, 8
	bleu	count, tmp1, L(copy0_8)
	/* Copy 9-16 bytes.  */
	ld	A_l, 0(src)
	ld	A_h, -8(srcend)
	sd	A_l, 0(dst)
	sd	A_h, -8(dstend)
	ret

	.p2align 3
L(copy0_8):
	li	tmp1, 4
	bleu	count, tmp1, L(copy0_4)
	/* Copy 5-8 bytes.  */
	lw	A_l, 0(src)
	lw	B_l, -4(srcend)
	sw	A_l, 0(dst)
	sw	B_l, -4(dstend)
	ret

L(copy0_4):
	li	tmp1, 2
	bleu	count, tmp1, L(copy0_2)
	/* Copy 3-4 bytes.  */
	lh	A_l, 0(src)
	lh	B_l, -2(srcend)
	sh	A_l, 0(dst)
	sh	B_l, -2(dstend)
	ret

L(copy0_2):
	li	tmp1, 1
	bleu	count, tmp1, L(copy0_1)
	/* Copy 2 bytes. */
	lh	A_l, 0(src)
	sh	A_l, 0(dst)
	ret

L(copy0_1):
	beqz	count, L(copy0)
	/* Copy 1 byte.  */
	lb	A_l, 0(src)
	sb	A_l, 0(dst)
L(copy0):
	ret

	.p2align 4
L(copy33_96):
	/* Copy 33-96 bytes.  */
	ld	A_l, 0(src)
	ld	A_h, 8(src)
	ld	B_l, 16(src)
	ld	B_h, 24(src)
	ld	C_l, -32(srcend)
	ld	C_h, -24(srcend)
	ld	D_l, -16(srcend)
	ld	D_h, -8(srcend)

	li	tmp1, 64
	bgtu	count, tmp1, L(copy65_96_preloaded)

	sd	A_l, 0(dst)
	sd	A_h, 8(dst)
	sd	B_l, 16(dst)
	sd	B_h, 24(dst)
	sd	C_l, -32(dstend)
	sd	C_h, -24(dstend)
	sd	D_l, -16(dstend)
	sd	D_h, -8(dstend)
	ret

	.p2align 4
L(copy65_96_preloaded):
	/* Copy 65-96 bytes with pre-loaded A, B, C and D.  */
	ld	E_l, 32(src)
	ld	E_h, 40(src)
	ld	F_l, 48(src) /* dst2 will be overwritten.  */
	ld	F_h, 56(src) /* srcend will be overwritten.  */

	sd	A_l, 0(dst)
	sd	A_h, 8(dst)
	sd	B_l, 16(dst)
	sd	B_h, 24(dst)
	sd	E_l, 32(dst)
	sd	E_h, 40(dst)
	sd	F_l, 48(dst)
	sd	F_h, 56(dst)
	sd	C_l, -32(dstend)
	sd	C_h, -24(dstend)
	sd	D_l, -16(dstend)
	sd	D_h, -8(dstend)
	ret

#ifdef COPY97_128
	.p2align 4
L(copy97_128_forward):
	/* Copy 97-128 bytes from front to back.  */
	ld	A_l, 0(src)
	ld	A_h, 8(src)
	ld	B_l, 16(src)
	ld	B_h, 24(src)
	ld	C_l, -16(srcend)
	ld	C_h, -8(srcend)
	ld	D_l, -32(srcend)
	ld	D_h, -24(srcend)
	ld	E_l, -48(srcend)
	ld	E_h, -40(srcend)
	ld	F_l, -64(srcend) /* dst2 will be overwritten.  */
	ld	F_h, -56(srcend) /* srcend will be overwritten.  */

	sd	A_l, 0(dst)
	sd	A_h, 8(dst)
	ld	A_l, 32(src)
	ld	A_h, 40(src)
	sd	B_l, 16(dst)
	sd	B_h, 24(dst)
	ld	B_l, 48(src)
	ld	B_h, 56(src)

	sd	C_l, -16(dstend)
	sd	C_h, -8(dstend)
	sd	D_l, -32(dstend)
	sd	D_h, -24(dstend)
	sd	E_l, -48(dstend)
	sd	E_h, -40(dstend)
	sd	F_l, -64(dstend)
	sd	F_h, -56(dstend)

	sd	A_l, 32(dst)
	sd	A_h, 40(dst)
	sd	B_l, 48(dst)
	sd	B_h, 56(dst)
	ret
#endif

	.p2align 4
	/* Copy 97+ bytes from front to back.  */
L(copy_long_forward):
#ifdef COPY97_128
	/* Avoid loop if possible.  */
	li	tmp1, 128
	ble	count, tmp1, L(copy97_128_forward)
#endif

	/* Copy 16 bytes and then align dst to 16-byte alignment.  */
	ld	D_l, 0(src)
	ld	D_h, 8(src)

	/* Round down to the previous 16 byte boundary (keep offset of 16).  */
	andi	tmp1, dst, 15
	andi	dst2, dst, -16
	sub	src, src, tmp1

	ld	A_l, 16(src)
	ld	A_h, 24(src)
	sd	D_l, 0(dst)
	sd	D_h, 8(dst)
	ld	B_l, 32(src)
	ld	B_h, 40(src)
	ld	C_l, 48(src)
	ld	C_h, 56(src)
	ld	D_l, 64(src)
	ld	D_h, 72(src)
	addi	src, src, 64

	/* Calculate loop termination position.  */
	addi	tmp1, dstend, -(16+128)
	bgeu	dst2, tmp1, L(copy64_from_end)

	/* Store 64 bytes in a loop.  */
	.p2align 4
L(loop64_forward):
	addi	src, src, 64
	sd	A_l, 16(dst2)
	sd	A_h, 24(dst2)
	ld	A_l, -48(src)
	ld	A_h, -40(src)
	sd	B_l, 32(dst2)
	sd	B_h, 40(dst2)
	ld	B_l, -32(src)
	ld	B_h, -24(src)
	sd	C_l, 48(dst2)
	sd	C_h, 56(dst2)
	ld	C_l, -16(src)
	ld	C_h, -8(src)
	sd	D_l, 64(dst2)
	sd	D_h, 72(dst2)
	ld	D_l, 0(src)
	ld	D_h, 8(src)
	addi	dst2, dst2, 64
	bltu	dst2, tmp1, L(loop64_forward)

L(copy64_from_end):
	ld	E_l, -64(srcend)
	ld	E_h, -56(srcend)
	sd	A_l, 16(dst2)
	sd	A_h, 24(dst2)
	ld	A_l, -48(srcend)
	ld	A_h, -40(srcend)
	sd	B_l, 32(dst2)
	sd	B_h, 40(dst2)
	ld	B_l, -32(srcend)
	ld	B_h, -24(srcend)
	sd	C_l, 48(dst2)
	sd	C_h, 56(dst2)
	ld	C_l, -16(srcend)
	ld	C_h, -8(srcend)
	sd	D_l, 64(dst2)
	sd	D_h, 72(dst2)
	sd	E_l, -64(dstend)
	sd	E_h, -56(dstend)
	sd	A_l, -48(dstend)
	sd	A_h, -40(dstend)
	sd	B_l, -32(dstend)
	sd	B_h, -24(dstend)
	sd	C_l, -16(dstend)
	sd	C_h, -8(dstend)
	ret

END (MEMCPY)
libc_hidden_builtin_def (MEMCPY)

ENTRY_ALIGN (MEMMOVE, 6)
	/* Calculate the end position.  */
	add	srcend, src, count
	add	dstend, dst, count

	/* Decide how to process.  */
	li	tmp1, 96
	bgtu	count, tmp1, L(move_long)
	li	tmp1, 32
	bgtu	count, tmp1, L(copy33_96)
	li	tmp1, 16
	bleu	count, tmp1, L(copy0_16)

	/* Copy 17-32 bytes.  */
	ld	A_l, 0(src)
	ld	A_h, 8(src)
	ld	B_l, -16(srcend)
	ld	B_h, -8(srcend)
	sd	A_l, 0(dst)
	sd	A_h, 8(dst)
	sd	B_l, -16(dstend)
	sd	B_h, -8(dstend)
	ret

#ifdef COPY97_128
	.p2align 4
L(copy97_128_backward):
	/* Copy 97-128 bytes from back to front.  */
	ld	A_l, -16(srcend)
	ld	A_h, -8(srcend)
	ld	B_l, -32(srcend)
	ld	B_h, -24(srcend)
	ld	C_l, -48(srcend)
	ld	C_h, -40(srcend)
	ld	D_l, -64(srcend)
	ld	D_h, -56(srcend)
	ld	E_l, -80(srcend)
	ld	E_h, -72(srcend)
	ld	F_l, -96(srcend) /* dst2 will be overwritten.  */
	ld	F_h, -88(srcend) /* srcend will be overwritten.  */

	sd	A_l, -16(dstend)
	sd	A_h, -8(dstend)
	ld	A_l, 16(src)
	ld	A_h, 24(src)
	sd	B_l, -32(dstend)
	sd	B_h, -24(dstend)
	ld	B_l, 0(src)
	ld	B_h, 8(src)

	sd	C_l, -48(dstend)
	sd	C_h, -40(dstend)
	sd	D_l, -64(dstend)
	sd	D_h, -56(dstend)
	sd	E_l, -80(dstend)
	sd	E_h, -72(dstend)
	sd	F_l, -96(dstend)
	sd	F_h, -88(dstend)

	sd	A_l, 16(dst)
	sd	A_h, 24(dst)
	sd	B_l, 0(dst)
	sd	B_h, 8(dst)
	ret
#endif

	.p2align 4
	/* Copy 97+ bytes.  */
L(move_long):
	/* dst-src is positive if src < dst.
	   In this case we must copy forward if dst-src >= count.
	   If dst-src is negative, then we can interpret the difference
	   as unsigned value to enforce dst-src >= count as well.  */
	sub	tmp1, dst, src
	beqz	tmp1, L(copy0)
	bgeu	tmp1, count, L(copy_long_forward)

#ifdef COPY97_128
	/* Avoid loop if possible.  */
	li	tmp1, 128
	ble	count, tmp1, L(copy97_128_backward)
#endif

	/* Copy 16 bytes and then align dst to 16-byte alignment.  */
	ld	D_l, -16(srcend)
	ld	D_h, -8(srcend)

	/* Round down to the previous 16 byte boundary (keep offset of 16).  */
	andi	tmp1, dstend, 15
	sub	srcend, srcend, tmp1

	ld	A_l, -16(srcend)
	ld	A_h, -8(srcend)
	ld	B_l, -32(srcend)
	ld	B_h, -24(srcend)
	ld	C_l, -48(srcend)
	ld	C_h, -40(srcend)
	sd	D_l, -16(dstend)
	sd	D_h, -8(dstend)
	ld	D_l, -64(srcend)
	ld	D_h, -56(srcend)
	andi	dstend, dstend, -16

	/* Calculate loop termination position.  */
	addi	tmp1, dst, 128
	bleu	dstend, tmp1, L(copy64_from_start)

	/* Store 64 bytes in a loop.  */
	.p2align 4
L(loop64_backward):
	addi	srcend, srcend, -64
	sd	A_l, -16(dstend)
	sd	A_h, -8(dstend)
	ld	A_l, -16(srcend)
	ld	A_h, -8(srcend)
	sd	B_l, -32(dstend)
	sd	B_h, -24(dstend)
	ld	B_l, -32(srcend)
	ld	B_h, -24(srcend)
	sd	C_l, -48(dstend)
	sd	C_h, -40(dstend)
	ld	C_l, -48(srcend)
	ld	C_h, -40(srcend)
	sd	D_l, -64(dstend)
	sd	D_h, -56(dstend)
	ld	D_l, -64(srcend)
	ld	D_h, -56(srcend)
	addi	dstend, dstend, -64
	bgtu	dstend, tmp1, L(loop64_backward)

L(copy64_from_start):
	ld	E_l, 48(src)
	ld	E_h, 56(src)
	sd	A_l, -16(dstend)
	sd	A_h, -8(dstend)
	ld	A_l, 32(src)
	ld	A_h, 40(src)
	sd	B_l, -32(dstend)
	sd	B_h, -24(dstend)
	ld	B_l, 16(src)
	ld	B_h, 24(src)
	sd	C_l, -48(dstend)
	sd	C_h, -40(dstend)
	ld	C_l, 0(src)
	ld	C_h, 8(src)
	sd	D_l, -64(dstend)
	sd	D_h, -56(dstend)
	sd	E_l, 48(dst)
	sd	E_h, 56(dst)
	sd	A_l, 32(dst)
	sd	A_h, 40(dst)
	sd	B_l, 16(dst)
	sd	B_h, 24(dst)
	sd	C_l, 0(dst)
	sd	C_h, 8(dst)
	ret

END (MEMMOVE)
libc_hidden_builtin_def (MEMMOVE)

#endif /* __riscv_xlen == 64  */
