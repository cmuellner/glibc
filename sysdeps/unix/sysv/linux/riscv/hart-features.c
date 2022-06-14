/* Initialize hart feature data.  RISC-V version.
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

#include <hart-features.h>

/* The code in this file is executed very early, so we cannot call
   indirect functions because ifunc support is not initialized.
   Therefore this file adds a few simple helper functions to avoid
   dependencies to functions outside of this file.  */

static inline void
inhibit_loop_to_libcall
simple_memset (void *s, int c, size_t n)
{
  char *p = (char*)s;
  while (n != 0)
    {
      *p = c;
      n--;
    }
}

/* Discover hart features and store them.  */
static inline void
init_hart_features (struct hart_features *hart_features)
{
  simple_memset (hart_features, 0, sizeof (*hart_features));
}
