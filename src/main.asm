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

;;; ----------------------------------------------------------------------------
;;; Bank switching macros by Tjoppen (slightly adapted)
RTSBank = $1FD9
JMPBank = $1FE6

;39 byte bootstrap macro
;Includes RTSBank, JMPBank routines and JMP to Start in Bank 7
	MAC END_SEGMENT_CODE
	;RTSBank
	;Perform a long RTS
	tsx
	lda $02,X
	;decode bank
	;bank 0: $1000-$1FFF
	;bank 1: $3000-$3FFF
	;...
	;bank 7: $F000-$FFFF
	lsr
	lsr
	lsr
	lsr
	lsr
	tax
        ;; $1FF8-$1FF9 are the 2 bankswitching hotspots when 2 using 2 banks
	nop $1FF8,X ;3 B
	rts
	;JMPBank
	;Perform a long jmp to (ptr)
	;The bank number is stored in the topmost three bits of (ptr)
	;Example usage:
	;   SET_POINTER ptr, Address
	;   jsr JMPBank
	;
	;$1FE6-$1FED
	lda banksw_ptr+1
	lsr
	lsr
	lsr
	lsr
	lsr
	tax
	;$1FEE-$1FF3
	nop $1FF8,X ;3 B
	jmp (banksw_ptr)   ;3 B
	ENDM

	MAC END_SEGMENT
.BANK	SET {1}
	echo "Bank",(.BANK)d,":", ((RTSBank + (.BANK * 8192)) - *)d, "free"

	ORG RTSBank + (.BANK * 4096)
	RORG RTSBank + (.BANK * 8192)
	END_SEGMENT_CODE
;$1FF4-$1FFB - These are the bankswitching hotspots - when 8 banks
;;; $1FF8-$1FF9 are the 2 bankswitching hotspots when 2 using 2 banks
	.byte 0,0,0,0
	.byte 0,0,0,$4C ;JMP Start (reading the instruction jumps to bank 7, i.e init address)
;$1FFC-1FFF
	.word $1FFB
	.word $1FFB
;Bank .BANK+1
	ORG $1000 + ((.BANK + 1) * 4096)
	RORG $1000 + ((.BANK + 1) * 8192)
	ENDM
; End of bank switching macro definitions

    MAC WAIT_TIMINT
.wait_timint
	lda TIMINT
	beq .wait_timint
    ENDM

;;;-----------------------------------------------------------------------------
;;; Code segment
	SEG code
	ORG $1000
        RORG $1000
;;; Bank 0 - main bank - everything bu the music player
BANK0_DATA_START equ *
        INCLUDE "bank1_data.asm"
        echo "Bank0 data size:", (* - BANK0_DATA_START)d, "bytes"
BANK0_CODE_START equ *
        INCLUDE "bank1_code.asm"
        echo "Bank0 code size:", (* - BANK0_CODE_START)d, "bytes"
        END_SEGMENT 0

;;; Bank 1 - music
BANK1_DATA_START equ *
        INCLUDE "bank0_data.asm"
        echo "Bank1 data size:", (* - BANK1_DATA_START)d, "bytes"
BANK1_CODE_START equ *
        INCLUDE "bank0_code.asm"
        echo "Bank1 code size:", (* - BANK1_CODE_START)d, "bytes"

init:   CLEAN_START		; Initializes Registers & Memory
        jsr main_init

main_loop:	SUBROUTINE
	VERTICAL_SYNC		; 4 scanlines Vertical Sync signal

.vblank:
;;; 47 vblank scanlines - 48th will be first kernel line
	lda #55
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
	lda #37
	sta TIM64T
        jsr main_overscan
	WAIT_TIMINT

	jmp main_loop

;;; Bank 1 END_SEGMENT
	echo "Bank 1 :", ((RTSBank + (1 * 8192)) - *)d, "free"
	ORG RTSBank + $1000
	RORG RTSBank + $2000
	END_SEGMENT_CODE
	;$1FF4-$1FFB
	.byte 0,0,0,0
	.byte 0,0,0,$4C
	;$1FFC-1FFF
	.word init
	.word init
