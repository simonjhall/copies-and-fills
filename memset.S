/*
	This is part of the "copies and fills" library by Simon Hall

	This function is all my own work.
	It is licensed under the GNU Lesser Public License version 2.1

	void *memset(void *dest, int c, size_t count);
*/
.global memset
.func memset
memset:
	cmp r2, #0			/* get out on no work */
	and r1, #0xff
	orr r1, r1, r1, lsl #8		/* fill out byte two */
	bxeq lr

	push {r0, lr}		/* we have to return r0 */

	/* align up the destination to 4b */
	tst r0, #3
	orr r1, r1, r1, lsl #16		/* and bytes three and four */
	beq skip_byte_alignment

byte_alignment_loop:
	subs r2, #1
	strb r1, [r0], #1
	popeq {r0, pc}		/* get out if we're out of bytes */

	tst r0, #3
	bne byte_alignment_loop

	/* we are now 4b aligned, and there is at least one byte of r2 to go */
skip_byte_alignment:
	tst r0, #31
	beq skip_word_alignment

word_alignment_loop:
	cmp r2, #4
	blt stray_bytes

	subs r2, #4
	str r1, [r0], #4
	popeq {r0, pc}		/* if no work left */

	tst r0, #31
	bne word_alignment_loop

	/* we are now 32b aligned */
skip_word_alignment:
	and r3, r2, #31		/* small work */
	bics r2, #31		/* bulk work */

	push {r4-r6}

	bic r4, r3, #3		/* words of work to go */
	beq bytes_and_words

	/* fill out our bytes */
	mov r4, r1
	mov r5, r1
	mov r6, r1
main_loop:
	subs r2, #32

	stmia r0!, {r1, r4, r5, r6}
	stmia r0!, {r1, r4, r5, r6}

	bne main_loop
	cmp r3, #0
	popeq {r4-r6}
	popeq {r0, pc}
	bic r4, r3, #3		/* redo this */

bytes_and_words:
	cmp r4, #0
	beq bytes
words:
	subs r4, #4
	str r1, [r0], #4
	bne words

	ands r3, #3
	popeq {r4-r6}
	popeq {r0, pc}
bytes:
	subs r3, #1
	strb r1, [r0], #1
	bne bytes

	pop {r4-r6}
	pop {r0, pc}
stray_bytes:
	cmp r2, #2

	strgtb r1, [r0], #1
	strgeb r1, [r0], #1
	strb r1, [r0], #1

	pop {r0, pc}
.endfunc
