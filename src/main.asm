;;;-----------------------------------------------------------------------------
;;; Header

	PROCESSOR 6502
	INCLUDE "vcs.h"		; Provides RIOT & TIA memory map
	INCLUDE "macro.h"	; This file includes some helper macros
        INCLUDE "all_constants.asm"

;;;-----------------------------------------------------------------------------
;;; RAM segment
	SEG.U   ram
	ORG     $0080
RAM_START equ *
        INCLUDE "all_variables.asm"
        echo "Used RAM:", (* - RAM_START)d, "bytes"

;;;-----------------------------------------------------------------------------
;;; Code segment
	SEG code
	ORG $F000

DATA_START equ *
        INCLUDE "all_data.asm"
        echo "DATA size:", (* - DATA_START)d, "bytes"

CODE_START equ *
        INCLUDE "all_code.asm"

init:   CLEAN_START		; Initializes Registers & Memory
        jsr main_init

    MAC WAIT_TIMINT
.wait_timint
	lda TIMINT
	beq .wait_timint
    ENDM

main_loop:	SUBROUTINE
	VERTICAL_SYNC		; 4 scanlines Vertical Sync signal

.vblank:
;;; 48 vblank scanlines
	lda #56
	sta TIM64T
        jsr main_vblank
	WAIT_TIMINT
        sta WSYNC               ; Resynchronize

.kernel:
;;; 230 kernal scanlines (PAL standard is 228)
	lda #17
	sta T1024T
        jsr main_kernel
	WAIT_TIMINT
        sta WSYNC

.overscan:
;;; 30+4 overscan scanlines (+ vertical sync)
	lda #36
	sta TIM64T
        jsr main_overscan
	WAIT_TIMINT

	jmp main_loop

	echo "CODE size:", (* - CODE_START)d, "bytes"
	echo "Used ROM:", (* - $F000)d, "bytes"
	echo "Remaining ROM:", ($FFFC - *)d, "bytes"

;;;-----------------------------------------------------------------------------
;;; Reset Vector
	SEG reset
	ORG $FFFC
	DC.W init
	DC.W init
