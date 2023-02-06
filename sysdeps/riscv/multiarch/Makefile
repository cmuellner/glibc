ifeq ($(subdir),string)
sysdep_routines += \
	memcpy_generic \
	memmove_generic \
	memcpy_rv64_unaligned \
	\
	memset_generic \
	memset_rv64_unaligned \
	memset_rv64_unaligned_cboz64 \
	\
	strlen_generic \
	strlen_zbb \
	\
	strcmp_generic \
	strcmp_zbb \
	strcmp_zbb_unaligned \
	strncmp_generic \
	strncmp_zbb
endif

# nscd uses atomic_spin_nop which in turn requires cpu_relax
ifeq ($(subdir),nscd)
routines += cpu_relax cpu_relax_impl
endif
