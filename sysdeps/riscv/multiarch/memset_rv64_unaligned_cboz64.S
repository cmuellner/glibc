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

#define dstin	a0
#define val	a1
#define count	a2
#define dst	a3
#define dstend	a4
#define tmp1	a5

#ifndef MEMSET
# define MEMSET __memset_rv64_unaligned_cboz64
#endif

/* cbo.zero can be used to improve the performance of memset-zero.
 * However, the performance gain depends on the amount of data
 * to be cleared. This threshold allows to set the minimum amount
 * of bytes to enable the cbo.zero loop.
 * To disable cbo.zero, set this threshold to 0. */
#ifndef CBO_ZERO_THRESHOLD
# define CBO_ZERO_THRESHOLD 128
#endif

/* Assumptions:
 * rv64i_zicboz, 64 byte cbo.zero block size, unaligned accesses.  */

ENTRY_ALIGN (MEMSET, 6)

	/* Repeat the byte.  */
	slli	tmp1, val, 8
	or	val, tmp1, a1
	slli	tmp1, val, 16
	or	val, tmp1, a1
	slli	tmp1, val, 32
	or	val, tmp1, val

	/* Calculate the end position.  */
	add	dstend, dstin, count

	/* Decide how to process.  */
	li	tmp1, 96
	bgtu	count, tmp1, L(set_long)
	li	tmp1, 16
	bgtu	count, tmp1, L(set_medium)

	/* Set 0..16 bytes.  */
	li	tmp1, 8
	bltu	count, tmp1, 1f
	/* Set 8..16 bytes.  */
	sd	val, 0(dstin)
	sd	val, -8(dstend)
	ret

	.p2align 3
	/* Set 0..7 bytes.  */
1:	li	tmp1, 4
	bltu	count, tmp1, 2f
	/* Set 4..7 bytes.  */
	sw	val, 0(dstin)
	sw	val, -4(dstend)
	ret

	/* Set 0..3 bytes.  */
2:	beqz	count, 3f
	sb	val, 0(dstin)
	li	tmp1, 2
	bltu	count, tmp1, 3f
	sh	val, -2(dstend)
3:	ret

	.p2align 3
	/* Set 17..96 bytes.  */
L(set_medium):
	sd	val, 0(dstin)
	sd	val, 8(dstin)
	li	tmp1, 64
	bgtu	count, tmp1, L(set96)
	sd	val, -16(dstend)
	sd	val, -8(dstend)
	li	tmp1, 32
	bleu	count, tmp1, 1f
	sd	val, 16(dstin)
	sd	val, 24(dstin)
	sd	val, -32(dstend)
	sd	val, -24(dstend)
1:	ret

	.p2align 4
	/* Set 65..96 bytes.  Write 64 bytes from the start and
	   32 bytes from the end.  */
L(set96):
	sd	val, 16(dstin)
	sd	val, 24(dstin)
	sd	val, 32(dstin)
	sd	val, 40(dstin)
	sd	val, 48(dstin)
	sd	val, 56(dstin)
	sd	val, -32(dstend)
	sd	val, -24(dstend)
	sd	val, -16(dstend)
	sd	val, -8(dstend)
	ret

	.p2align 4
	/* Set 97+ bytes.  */
L(set_long):
	/* Store 16 bytes unaligned.  */
	sd	val, 0(dstin)
	sd	val, 8(dstin)

#if CBO_ZERO_THRESHOLD
	li	tmp1, CBO_ZERO_THRESHOLD
	blt	count, tmp1, 1f
	beqz	val, L(cbo_zero_64)
1:
#endif

	/* Round down to the previous 16 byte boundary (keep offset of 16).  */
	andi	dst, dstin, -16

	/* Calculate loop termination position.  */
	addi	tmp1, dstend, -(16+64)

	/* Store 64 bytes in a loop.  */
	.p2align 4
1:	sd	val, 16(dst)
	sd	val, 24(dst)
	sd	val, 32(dst)
	sd	val, 40(dst)
	sd	val, 48(dst)
	sd	val, 56(dst)
	sd	val, 64(dst)
	sd	val, 72(dst)
	addi	dst, dst, 64
	bltu	dst, tmp1, 1b

	/* Calculate remainder (dst2 is 16 too less).  */
	sub	count, dstend, dst

	/* Check if we have more than 32 bytes to copy.  */
	li	tmp1, (32+16)
	ble	count, tmp1, 1f
	sd	val, 16(dst)
	sd	val, 24(dst)
	sd	val, 32(dst)
	sd	val, 40(dst)
1:	sd	val, -32(dstend)
	sd	val, -24(dstend)
	sd	val, -16(dstend)
	sd	val, -8(dstend)
	ret

#if CBO_ZERO_THRESHOLD
	.option push
	.option arch,+zicboz
	.p2align 3
L(cbo_zero_64):
	/* Align dst (down).  */
	sd	val, 16(dstin)
	sd	val, 24(dstin)
	sd	val, 32(dstin)
	sd	val, 40(dstin)
	sd	val, 48(dstin)
	sd	val, 56(dstin)

	/* Round up to the next 64 byte boundary.  */
	andi	dst, dstin, -64
	addi	dst, dst, 64

	/* Calculate loop termination position.  */
	addi	tmp1, dstend, -64

	/* cbo.zero sets 64 bytes each time. */
	.p2align 4
1:	cbo.zero	(dst)
	addi	dst, dst, 64
	bltu	dst, tmp1, 1b

	sub	count, dstend, dst
	li	tmp1, 32
	ble	count, tmp1, 1f
	sd	val, 0(dst)
	sd	val, 8(dst)
	sd	val, 16(dst)
	sd	val, 24(dst)
1:	sd	val, -32(dstend)
	sd	val, -24(dstend)
	sd	val, -16(dstend)
	sd	val, -8(dstend)
	ret
	.option pop
#endif /* CBO_ZERO_THRESHOLD  */

END (MEMSET)
libc_hidden_builtin_def (MEMSET)

#endif /* __riscv_xlen == 64  */
