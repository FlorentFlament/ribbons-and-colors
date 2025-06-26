;;; Uses A register
text_init:	SUBROUTINE
        INCLUDE "bossa-novayaska_init.asm"
	;; No reflection - 1 copy small
	lda #$00
	sta REFP0
	sta REFP1
	sta NUSIZ0
	sta NUSIZ1
        sta COLUBK
        sta COLUPF
        ;; Mirror playfield
        lda #$01
        sta CTRLPF
        lda #$cf
        sta PF0
        lda #$ff
        sta PF1
        sta PF2
        ;; Sprites color
        lda #$ff
        sta COLUP0
        sta COLUP1
	rts

text_vblank:	SUBROUTINE
        jsr tia_player          ; Play the music

        ;; Compute line_cnt offset from frame counter
        ;lda frame_cnt
        ;sta line_cnt
        ;lda frame_cnt+1
        ;ror
        ;tax
        ;lda line_cnt
        ;ror
        ;sta line_cnt
        ;txa
        ;ror
        ;lda line_cnt
        ;ror
        ;sta line_cnt
        ;eor #$ff
        ;sta line_cnt

	rts

text_overscan:  SUBROUTINE
        rts

;;; Position Sprites according to sp0_pos and sp1_pos
;;; sp0_pos and sp1_ops respectively contain sprite0 and sprite1 positions
;;; Macro argument is 0 or 1, the sprite to position
;;; This consumes a display line
;;; Uses A register
        MAC COARSE_POSITION_ONE_SPRITE
        ;; Clear sprites there to avoid wasting a scanline
        lda #$00
        sta GRP0
        sta GRP1
        sec
        ;; coarse loop consumes 15 pixels (3 * 5cycles)
        lda sp{1}_pos
.coarse_loop:
        sbc #$0f
        bcs .coarse_loop
        sta RESP{1}
        sta sp{1}_pos           ; Save remaining pixels for fine move
        ENDM

;;; Fine position using sp0_pos or sp1_pos
;;; Macro argument is 0 or 1, for positionning sprite 0 or sprite 1
;;; Uses A register
        MAC FINE_POSITION_ONE_SPRITE
        sec
        lda sp{1}_pos
        eor #$ff
        sbc #$08
        REPEAT 4
        asl
        REPEND
        sta HMP{1}
        ENDM

text_kernel:	SUBROUTINE
        SET_POINTER bg_ptr,bg_table
        SET_POINTER sp0_ptr,sp0_table
        SET_POINTER sp1_ptr,sp1_table

        ;; Header offset
        clc
        lda frame_cnt
        and #$0f                ; in [0  , 15]
        eor #$ff                ; in [-16, -1]
        adc #$0f                ; in [-1 , 14]
        bmi .display_column
        tay
.header_loop:
        lda (bg_ptr),Y
        sta WSYNC
        sta COLUPF
        dey
        bpl .header_loop

.display_column:
        lda #11
        sta sprite_cnt
.column_loop:
        ;; Width is 144 pixels = 160 - 16 (2x8 borders)
        ;; First pixel for sp0_pos = #17
        ;; First out of screen pix for #161
        lda #40              ; Fetch sprite0 position - 8 is left edge
        sta sp0_pos
        lda #112          ; Fetch sprite1 position - 144 is right edge
        sta sp1_pos

.sprite_header:
        ldy #15
        lda (bg_ptr),Y
        sta WSYNC
        sta COLUPF
        COARSE_POSITION_ONE_SPRITE 0
        dey
        lda (bg_ptr),Y
        sta WSYNC
        sta COLUPF
        COARSE_POSITION_ONE_SPRITE 1
        dey
        lda (bg_ptr),Y
        sta WSYNC
        sta COLUPF
        FINE_POSITION_ONE_SPRITE 0
        FINE_POSITION_ONE_SPRITE 1

        dey                     ; y is now #12
.sprite_body:
        sta WSYNC
        ;; (1) Trick do reduce sprites vertical spacing
        ;; by commiting horizontal moves while setting sprites pixels
        sta HMOVE

        lda (bg_ptr),Y
        sta COLUPF
        lda (sp0_ptr),Y
        sta GRP0
        lda (sp1_ptr),Y
        sta GRP1

        ;; Don't move sprites further - Part of trick (1)
        ;; Enough cycles need be consumed earlier
        lda #$00
        sta HMP0
        sta HMP1

        dey
        bpl .sprite_body

        ldx sprite_cnt
        dex
        stx sprite_cnt
        bmi .end
        jmp .column_loop
.end:

        sta WSYNC
        lda #$00
        sta GRP0
        sta GRP1
        sta COLUPF
        rts

bg_table:
        dc.b $90, $90, $92, $92, $94, $94, $96, $96
        dc.b $98, $98, $96, $96, $94, $94, $92, $92

sp0_table:
        dc.b $ff, $7e, $3c, $18, $18, $3c, $7e, $ff
        dc.b $ff, $7e, $3c, $18, $18, $3c, $7e, $ff

sp1_table:
        dc.b $18, $3c, $7e, $ff, $ff, $7e, $3c, $18
        dc.b $18, $3c, $7e, $ff, $ff, $7e, $3c, $18
