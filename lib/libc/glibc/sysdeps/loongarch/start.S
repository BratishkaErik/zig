/* Startup code compliant to the ELF LoongArch ABI.
   Copyright (C) 2022-2025 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   In addition to the permissions in the GNU Lesser General Public
   License, the Free Software Foundation gives you unlimited
   permission to link the compiled version of this file with other
   programs, and to distribute those programs without any restriction
   coming from the use of this file. (The GNU Lesser General Public
   License restrictions do apply in other respects; for example, they
   cover modification of the file, and distribution when not linked
   into another program.)

   Note that people who make modified versions of this file are not
   obligated to grant this special exception for their modified
   versions; it is their choice whether to do so. The GNU Lesser
   General Public License gives permission to release a modified
   version without this exception; this exception also makes it
   possible to release a modified version which carries forward this
   exception.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#define __ASSEMBLY__ 1
#include <entry.h>
#include <sys/asm.h>

/* The entry point's job is to call __libc_start_main.  Per the ABI,
   a0 contains the address of a function to be passed to atexit.
   __libc_start_main wants this in a5.  */

/*
int
__libc_start_main (int (*main) (int, char **, char **),
		   int argc,
		   char **argv,
		   __typeof (main) init,
		   void (*fini) (void),
		   void (*rtld_fini) (void),
		   void *stack_end);
 */

ENTRY (ENTRY_POINT)

/* Terminate call stack by noting ra is undefined.  Use a dummy
   .cfi_label to force starting the FDE.  */
	.cfi_label .Ldummy
	cfi_undefined (1)
	or		a5, a0, zero /* rtld_fini */

	la.pcrel	a0, t0, main
	REG_L		a1, sp, 0
	ADDI		a2, sp, SZREG

	/* Adjust $sp for 16-aligned */
	BSTRINS		sp, zero, 3, 0

	move		a3, zero /* used to be init */
	move		a4, zero /* used to be fini */
	or		a6, sp, zero /* stack_end */

	la.pcrel	ra, t0, __libc_start_main
	jirl		ra, ra, 0

	la.pcrel	ra, t0, abort
	jirl		ra, ra, 0
END (ENTRY_POINT)
