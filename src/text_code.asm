text_init:	SUBROUTINE
        INCLUDE "chloe-eclot_trackinit.asm"
	;; No reflection - 1 copy small
	lda #$00
	sta REFP0
	sta REFP1
	sta NUSIZ0
	sta NUSIZ1
        ;; Sprites color
        lda #$ff
        sta COLUP0
        sta COLUP1
	rts

text_vblank:	SUBROUTINE
        jsr tia_player          ; Play the music
	rts

text_overscan:  SUBROUTINE
        rts

text_kernel:	SUBROUTINE
        ;; Coarse positioning
        sta WSYNC
        ldx #8
.rough_p0_0:
        dex
        bne .rough_p0_0
        sta RESP0
        sta RESP1

        ;; Fine positioning
        lda #$00
        sta HMP0
        lda #$00
        sta HMP1

        ;; Commit position and set player color
        sta WSYNC
        sta HMOVE
        lda #$ff
        sta GRP0
        sta GRP1

        ;; for 7 lines
        ldx #7
.block_loop_0:
        sta WSYNC
        dex
        bne .block_loop_0

        sta WSYNC
        ldx #6
.rough_p0_1:
        dex
        bne .rough_p0_1
        sta RESP0
        sta RESP1

        ;; Fine positioning
        lda #$00
        sta HMP0
        lda #$00
        sta HMP1

        ;; Commit position and set player color
        sta WSYNC
        sta HMOVE
        lda #$ff
        sta GRP0
        sta GRP1

        ;; for 7 lines
        ldx #7
.block_loop_1:
        sta WSYNC
        dex
        bne .block_loop_1

        sta WSYNC
        lda #$00
        sta GRP0
        sta GRP1

        rts
