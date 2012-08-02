/*
	Part of the "copies and fills" library by Simon Hall

	The inner loop of the misaligned path is derived from the GNU libc ARM port.
	The rest is my own work.

	This code is licensed under the GNU Lesser General Public License version 2.1

		void memcpy(void *dest,
                        const void *source,
                        size_t count);
*/

.global memcpy
.func memcpy
memcpy:
	cmp r2, #0
	pld [r1]
	bxeq lr					/* get straight out on zero, NB: count is unsigned */

	cmp r2, #4				/* basic copy for four bytes */
	pld [r1, #32]
	ldreq r3, [r1]				/* we're relying on the cpu misalignment support here */
	streq r3, [r0]
	bxeq lr

	cmp r2, #8
	pld [r1, #64]				/* basic copy for eight bytes, with fall through for < 8 */
	ldreq r3, [r1]				/* can't use ldrd without checking alignment...can't trust os alignment handling */
	streq r3, [r0]				/* if we do trust the os then r2 is free for ldrd */
	ldreq r3, [r1, #4]
	streq r3, [r0, #4]
	bxeq lr

	cmp r2, #32
	pld [r1, #96]
	blt byte_at_a_time_no_pld		/* fast path for small sizes, no stack push */

	push {r0, r4-r11}			/* memcpy returns the original destination, hence push r0 */

	/* compute the dest pointer alignment */
.if 0
	and r3, r0, #3			/* slightly slower compared to conditional version below */

	cmp r3, #3				/* three bytes misaligned, one to do */
	beq head_1

	cmp r3, #2
	beq head_2				/* two bytes misaligned, two to do */

	cmp r3, #1
	beq head_3				/* one byte misaligned, three to do */
.else
	ands r3, r0, #3
	beq skip_byte_realignment

	rsb r4, r3, #4			/* how many bytes need to be read */
	cmp r4, #2

	ldrgtb r5, [r1], #1		/* three bytes */
	ldrgeb r6, [r1], #1		/* two+ bytes */
	ldrb r7, [r1], #1		/* one+ byte */

	strgtb r5, [r0], #1
	strgeb r6, [r0], #1
	strb r7, [r0], #1

	sub r2, r4

skip_byte_realignment:
.endif

.if 0
	eor r3, r0, r1				/* check the 4b alignment of the two pointers */
	tst r3, #3				/* ideally the bottom two bits should line up */

.else
	ands r3, r1, #3
.endif
	bne misaligned

	/* dest pointer now 4b aligned */
	/* let's try and 32b align the destination */
	tst r0, #31
	beq pre_fast_loop
align_up:
.if 1
	ldr r3, [r1], #4

	add r0, #4
	sub r2, #4

	tst r0, #31				/* do it early for the next run */
	str r3, [r0, #-4]

	bne align_up
.else
	and r3, r0, #31			/* jump based on the amount of bytes to do - slower than loop above */
	add pc, pc, r3
	nop; nop

	ldr r4, [r1], #4
	ldr r5, [r1], #4
	ldr r6, [r1], #4
	ldr r7, [r1], #4
	ldr r8, [r1], #4
	ldr r9, [r1], #4
	ldr r10, [r1], #4

	add pc, pc, r3
	nop; nop

	str r4, [r0], #4
	str r5, [r0], #4
	str r6, [r0], #4
	str r7, [r0], #4
	str r8, [r0], #4
	str r9, [r0], #4
	str r10, [r0], #4

	rsb r3, #32
	sub r2, r3
.endif

pre_fast_loop:
	/* round byte count down to nearest 32 */
	bics r3, r2, #31
	/* compute the spare */
	and r2, #31

	beq post_fast_loop			/* nothing to do in the main loop */

	/* work through 32b at a time */
fast_loop:
.if 0
	ldmia r1!, {r4-r11}		/* original version */
	subs r3, #32
	stmia r0!, {r4-r11}
	pld [r1, #128]
	bne fast_loop
.else
	ldmia r1!, {r4-r7}		/* slightly fast version suggested by tufty */
	ldmia r1!, {r8-r11}
	stmia r0!, {r4-r7}
	pld [r1, #128]
	subs r3, #32
	stmia r0!, {r8-r11}
	bne fast_loop
.endif

	/* handle the spare bytes, up to 32 of them */
post_fast_loop:
	cmp r2, #0		/* there might be none */
	beq full_out

	bics r3, r2, #3
	and r2, #3
	beq tail_fast_loop_byte

tail_fast_loop:
	ldr r4, [r1], #4
	subs r3, #4
	str r4, [r0], #4
	bne tail_fast_loop

	cmp r2, #0
	beq full_out

tail_fast_loop_byte:
	subs r2, #1
	ldrb r3, [r1], #1
	strb r3, [r0], #1
	bne tail_fast_loop_byte

full_out:
	pop {r0, r4-r11}
	bx lr

byte_at_a_time_no_pld:
	subs r2, #1
	ldrb r3, [r1, r2]			/* one byte at a time, so we don't have to check for odd */
	strb r3, [r0, r2]			/* sizes and alignments etc; also no stack push necessary */
	bne byte_at_a_time_no_pld

	bx lr					/* leaving r0 intact */

/*head_3:
	ldrb r3, [r1], #1
    strb r3, [r0], #1
    sub r2, #1
head_2:
	ldrb r3, [r1], #1
    strb r3, [r0], #1
    sub r2, #1
head_1:
	ldrb r3, [r1], #1
	strb r3, [r0], #1
	sub r2, #1
	b pre_fast_loop
*/
misaligned:
	bic r1, #3					/* align down r1, with r3 containing the r1 misalignment */
	cmp r3, #2
	ldr r11, [r1], #4

	beq misaligned_2
	bgt misaligned_3
misaligned_1:
	cmp r2, #32
	blt post_misalignment_1

mis_1_loop:
	lsr r3, r11, #8				/* we want the high three bytes of this */
	ldmia r1!, {r4-r11}
	sub r2, #32
	cmp r2, #32

	orr r3, r4, lsl #24
	lsr r4, #8; orr r4, r5, lsl #24
	lsr r5, #8; orr r5, r6, lsl #24
	lsr r6, #8; orr r6, r7, lsl #24
	lsr r7, #8; orr r7, r8, lsl #24
	lsr r8, #8; orr r8, r9, lsl #24
	lsr r9, #8; orr r9, r10, lsl #24
	lsr r10, #8; orr r10, r11, lsl #24

	pld [r1, #128]
	stmia r0!, {r3-r10}

	bge mis_1_loop

post_misalignment_1:
	cmp r2, #0
	beq full_out
	lsr r11, #8
	mov r3, #3
post_misalignment_1_loop:
	cmp r3, #0
	ldreq r11, [r1], #4
	moveq r3, #4

	strb r11, [r0], #1
	sub r3, #1
	subs r2, #1
	lsr r11, #8
	bne post_misalignment_1_loop

	b full_out

misaligned_2:
	cmp r2, #32
	blt post_misalignment_2

mis_2_loop:
	lsr r3, r11, #16				/* we want the high two bytes of this */
	ldmia r1!, {r4-r11}
	sub r2, #32
	cmp r2, #32

	orr r3, r4, lsl #16
	lsr r4, #16; orr r4, r5, lsl #16
	lsr r5, #16; orr r5, r6, lsl #16
	lsr r6, #16; orr r6, r7, lsl #16
	lsr r7, #16; orr r7, r8, lsl #16
	lsr r8, #16; orr r8, r9, lsl #16
	lsr r9, #16; orr r9, r10, lsl #16
	lsr r10, #16; orr r10, r11, lsl #16

	pld [r1, #128]
	stmia r0!, {r3-r10}

	bge mis_2_loop

post_misalignment_2:
	cmp r2, #0
	beq full_out
	lsr r11, #16
	mov r3, #2
post_misalignment_2_loop:
	cmp r3, #0
	ldreq r11, [r1], #4
	moveq r3, #4

	strb r11, [r0], #1
	sub r3, #1
	subs r2, #1
	lsr r11, #8
	bne post_misalignment_2_loop
	
	b full_out
misaligned_3:
	cmp r2, #32
	blt post_misalignment_3

mis_3_loop:
	lsr r3, r11, #24				/* we want the high byte of this */
	ldmia r1!, {r4-r11}
	sub r2, #32
	cmp r2, #32

	orr r3, r4, lsl #8
	lsr r4, #24; orr r4, r5, lsl #8
	lsr r5, #24; orr r5, r6, lsl #8
	lsr r6, #24; orr r6, r7, lsl #8
	lsr r7, #24; orr r7, r8, lsl #8
	lsr r8, #24; orr r8, r9, lsl #8
	lsr r9, #24; orr r9, r10, lsl #8
	lsr r10, #24; orr r10, r11, lsl #8

	pld [r1, #128]
	stmia r0!, {r3-r10}

	bge mis_3_loop

post_misalignment_3:
	cmp r2, #0
	beq full_out
	lsr r11, #24
	mov r3, #1
post_misalignment_3_loop:
	cmp r3, #0
	ldreq r11, [r1], #4
	moveq r3, #4

	strb r11, [r0], #1
	sub r3, #1
	subs r2, #1
	lsr r11, #8
	bne post_misalignment_3_loop
	
	b full_out
.endfunc
