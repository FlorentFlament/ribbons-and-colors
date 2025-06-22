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
        ldy #$16

.big_loop:
        lda #$ff
        ldx #$ff
        sta WSYNC

        sta GRP0
        stx GRP1

        ldx #$05
.rough_p0:
        dex
        bne .rough_p0
        sta RESP0
        sta RESP1

        lda #$07
        sta HMP0
        lda #$60
        sta HMP1

        dey
        bne .big_loop

        lda #$00
        sta GRP0
        sta GRP1

        rts
