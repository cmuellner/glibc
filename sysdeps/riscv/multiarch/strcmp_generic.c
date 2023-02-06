/* strcmp for RISC-V, default version for internal use.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#include <string.h>

#define STRCMP __strcmp_generic

#ifdef SHARED
# undef libc_hidden_builtin_def
# define libc_hidden_builtin_def(name) \
  __hidden_ver1(__strcmp_generic, __GI_strcmp, __strcmp_generic);
#endif

extern int __strcmp_generic(const char *s1, const char *s2);

#include <string/strcmp.c>
