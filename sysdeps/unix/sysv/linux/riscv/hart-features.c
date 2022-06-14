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
#include <macro-for-each.h>
#include <string_private.h>

/* The code in this file is executed very early, so we cannot call
   indirect functions because ifunc support is not initialized.
   Therefore this file adds a few simple helper functions to avoid
   dependencies to functions outside of this file.  */

#define xstr(s) str(s)
#define str(s) #s

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

static inline size_t
inhibit_loop_to_libcall
simple_strlen (const char *s)
{
  size_t n = 0;
  char c = *s;
  while (c != 0)
    {
      s++;
      n++;
      c = *s;
    }
  return n;
}

static inline int
inhibit_loop_to_libcall
simple_strncmp (const char *s1, const char *s2, size_t n)
{
  while (n != 0)
    {
      if (*s1 == 0 || *s1 != *s2)
	return *((const unsigned char *)s1) - *((const unsigned char *)s2);
      n--;
      s1++;
      s2++;
    }
  return 0;
}

extern char **__environ;
static inline char*
simple_getenv (const char *name)
{
  char **ep;
  uint16_t name_start;

  if (__environ == NULL || name[0] == 0 || name[1] == 0)
    return NULL;

  size_t len = simple_strlen (name);
#if _STRING_ARCH_unaligned
  name_start = *(const uint16_t *) name;
#else
  name_start = (((const unsigned char *) name)[0]
		| (((const unsigned char *) name)[1] << 8));
#endif
  len -= 2;
  name += 2;

  for (ep = __environ; *ep != NULL; ++ep)
    {
#if _STRING_ARCH_unaligned
      uint16_t ep_start = *(uint16_t *) *ep;
#else
      uint16_t ep_start = (((unsigned char *) *ep)[0]
			   | (((unsigned char *) *ep)[1] << 8));
#endif
      if (name_start == ep_start && !simple_strncmp (*ep + 2, name, len)
	  && (*ep)[len + 2] == '=')
	return &(*ep)[len + 3];
    }
  return NULL;
}

/* Check if the given number is a power of 2.
   Return true if so, or false otherwise.  */
static inline int
is_power_of_two (unsigned long v)
{
  return (v & (v - 1)) == 0;
}

/* Check if the given string str starts with
   the prefix pre.  Return true if so, or false
   otherwise.  */
static inline int
starts_with (const char *str, const char *pre)
{
  return simple_strncmp (pre, str, simple_strlen (pre)) == 0;
}

/* Lower all characters of a string up to the
   first NUL-character in the string.  */
static inline void
strtolower (char *s)
{
  char c = *s;
  while (c != '\0')
    {
      if (c >= 'A' && c <= 'Z')
	*s = c + 'a' - 'A';
      s++;
      c = *s;
    }
}

/* Count the number of detected extensions.  */
static inline unsigned long
count_extensions (struct hart_features *hart_features)
{
  unsigned long n = 0;
#define ISA_EXT(e)							\
  if (hart_features->have_##e == 1)					\
    n++;
#define ISA_EXT_GROUP(g, ...)						\
  if (hart_features->have_##g == 1)					\
    n++;
#include "isa-extensions.def"
  return n;
}

/* Check if the given charater is not '0'-'9'.  */
static inline int
notanumber (const char c)
{
  return (c < '0' || c > '9');
}

/* Parse RISCV_RT_MARCH and store found extensions.  */
static inline void
parse_rt_march (struct hart_features *hart_features)
{
  const char* s = simple_getenv ("RISCV_RT_MARCH");
  if (s == NULL)
    goto end;

  hart_features->rt_march = s;

  /* "RISC-V ISA strings begin with either RV32I, RV32E, RV64I, or RV128I
      indicating the supported address space size in bits for the base
      integer ISA."  */
  if (starts_with (s, "rv32") && notanumber (*(s+4)))
    {
      hart_features->xlen = 32;
      s += 4;
    }
  else if (starts_with (s, "rv64") && notanumber (*(s+4)))
    {
      hart_features->xlen = 64;
      s += 4;
    }
  else if (starts_with (s, "rv128") && notanumber (*(s+5)))
    {
      hart_features->xlen = 128;
      s += 5;
    }
  else
    {
      goto fail;
    }

  /* Parse the extensions.  */
  const char *s_old = s;
  while (*s != '\0')
    {
#define ISA_EXT(e)							\
      else if (starts_with (s, xstr (e)))				\
	{								\
	  hart_features->have_##e = 1;					\
	  s += simple_strlen (xstr (e));				\
	}
#define ISA_EXT_GROUP(g, ...)						\
      ISA_EXT (g)
      if (0);
#include "isa-extensions.def"

      /* Consume optional version information.  */
      while (*s >= '0' && *s <= '9')
	s++;
      while (*s == 'p')
	s++;
      while (*s >= '0' && *s <= '9')
	s++;

      /* Consume optional '_'.  */
      if (*s == '_')
	s++;

      /* If we got stuck, bail out.  */
      if (s == s_old)
	goto fail;
    }

  /* Propagate subsets (until we reach a fixpoint).  */
  unsigned long n = count_extensions (hart_features);
  while (1)
    {
      /* Forward-propagation.  E.g.:
      if (hart_features->have_g == 1)
	{
	  hart_features->have_i = 1;
	  ...
	  hart_features->have_zifencei = 1;
	}  */
#define ISA_EXT_GROUP_HEAD(y)						\
      if (hart_features->have_##y)					\
	{
#define ISA_EXT_GROUP_SUBSET(s)						\
	  hart_features->have_##s = 1;
#define ISA_EXT_GROUP_TAIL(z)						\
	}
#define ISA_EXT_GROUP(x, ...)						\
	ISA_EXT_GROUP_HEAD (x)						\
	FOR_EACH (ISA_EXT_GROUP_SUBSET, __VA_ARGS__)			\
	ISA_EXT_GROUP_TAIL (x)
#include "isa-extensions.def"
#undef ISA_EXT_GROUP_HEAD
#undef ISA_EXT_GROUP_SUBSET
#undef ISA_EXT_GROUP_TAIL

      /* Backward-propagation.  E.g.:
      if (1
	  && hart_features->have_i == 1
	  ...
	  && hart_features->have_zifencei == 1
	  )
	hart_features->have_g = 1;  */
#define ISA_EXT_GROUP_HEAD(y)						\
      if (1
#define ISA_EXT_GROUP_SUBSET(s)						\
	  && hart_features->have_##s == 1
#define ISA_EXT_GROUP_TAIL(z)						\
	  )								\
	hart_features->have_##z = 1;
#define ISA_EXT_GROUP(x, ...)						\
	ISA_EXT_GROUP_HEAD (x)						\
	FOR_EACH (ISA_EXT_GROUP_SUBSET, __VA_ARGS__)			\
	ISA_EXT_GROUP_TAIL (x)
#include "isa-extensions.def"
#undef ISA_EXT_GROUP_HEAD
#undef ISA_EXT_GROUP_SUBSET
#undef ISA_EXT_GROUP_TAIL

      unsigned long n2 = count_extensions (hart_features);
      /* Stop if fix-point reached.  */
      if (n == n2)
	break;
      n = n2;
    }

end:
  return;

fail:
  hart_features->rt_march = NULL;
}

/* Parse RISCV_RT_CBOM_BLOCKSIZE and store value.  */
static inline void
parse_rt_cbom_blocksize (struct hart_features *hart_features)
{
  hart_features->rt_cbom_blocksize = NULL;
  hart_features->cbom_blocksize = 0;

  const char *s = simple_getenv ("RISCV_RT_CBOM_BLOCKSIZE");
  if (s == NULL)
    return;

  uint64_t v = _dl_strtoul (s, NULL);
  if (!is_power_of_two (v))
    return;

  hart_features->rt_cbom_blocksize = s;
  hart_features->cbom_blocksize = v;
}

/* Parse RISCV_RT_CBOZ_BLOCKSIZE and store value.  */
static inline void
parse_rt_cboz_blocksize (struct hart_features *hart_features)
{
  hart_features->rt_cboz_blocksize = NULL;
  hart_features->cboz_blocksize = 0;

  const char *s = simple_getenv ("RISCV_RT_CBOZ_BLOCKSIZE");
  if (s == NULL)
    return;

  uint64_t v = _dl_strtoul (s, NULL);
  if (!is_power_of_two (v))
    return;

  hart_features->rt_cboz_blocksize = s;
  hart_features->cboz_blocksize = v;
}

/* Discover hart features and store them.  */
static inline void
init_hart_features (struct hart_features *hart_features)
{
  simple_memset (hart_features, 0, sizeof (*hart_features));
  parse_rt_march (hart_features);
  parse_rt_cbom_blocksize (hart_features);
  parse_rt_cboz_blocksize (hart_features);
}
