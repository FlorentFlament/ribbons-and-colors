BORDER_COLOR = $ff

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

        lda #$01                ; Mirror playfield
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
	rts

text_overscan:  SUBROUTINE
        rts

;; Position Sprites according to sp0_pos and sp1_pos
        ;; sp0_pos and sp1_ops respectively contain sprite0 and sprite1 positions

sp0_pos = ptr1
sp1_pos = ptr1 + 1
;;; Macro argument is 0 or 1, the sprite to position
;;; This consumes a display line
        MAC POSITION_ONE_SPRITE
        sta WSYNC
        ;; Clear sprites there to avoid wasting a scanline
        lda #$00
        sta GRP0
        sta GRP1

        ;; Coarse positioning
        lda sp{1}_pos
        ;; coarse loop consumes 15 pixels (3 * 5cycles)
.coarse_loop:
        sbc #$0f
        bcs .coarse_loop
        sta RESP{1}

        adc #$07
        eor #$ff
        REPEAT 4
        asl
        REPEND
        sta sp{1}_pos           ; Remaining pixels to adjust for
        ENDM

;;; Position the 2 VCS sprites
;;; sp0_pos and sp1_pos contain their respective positions
;;; Consumes 2 display lines
;;; WSYNC and HMOVE need to be performed after that
        MAC POSITION_BOTH_SPRITES
        ;; Coarse positioning
        POSITION_ONE_SPRITE 0
        POSITION_ONE_SPRITE 1

        ;; Fine tune sprites position
        lda sp0_pos
        sta HMP0
        lda sp1_pos
        sta HMP1
        ENDM

sprite_it  = ptr0
sprite_cnt = ptr0 + 1
text_kernel:	SUBROUTINE
        ldx #12
        stx sprite_cnt
.column_loop:
        ldx #150                ; Fetch sprite0 position
        stx sp0_pos
        ldx #30                 ; Fetch sprite1 position
        stx sp1_pos
        POSITION_BOTH_SPRITES

        ldx #11
        stx sprite_it
.sprite_loop:
        sta WSYNC
        ;; (1) Trick do reduce sprites vertical spacing
        ;; by commiting horizontal moves while setting sprites pixels
        sta HMOVE

        lda sprite_cnt          ; Fetch background color
        and #$07
        tax
        lda bg_table,X
        sta COLUPF
        lda #$ff                ; Fetch sprite0 data
        sta GRP0
        lda #$ff                ; Fetch sprite1 data
        sta GRP1

        ;; Don't move sprites further - Part of trick (1)
        ;; Enough cycles need be consumed earlier
        lda #$00
        sta HMP0
        sta HMP1

        ldx sprite_it
        dex
        stx sprite_it
        bpl .sprite_loop

        ldx sprite_cnt
        dex
        stx sprite_cnt
        bpl .column_loop

        sta WSYNC
        lda #$00
        sta GRP0
        sta GRP1
        sta COLUPF
        rts

bg_table:
        dc.b    $90, $92, $94, $96, $98, $96, $94, $92

circle_positions_up:
        dc.b    $00
        dc.b    $02, $03, $04, $05, $02, $03, $04, $05
        dc.b    $00, $01, $02, $03, $02, $03, $04, $05
hmove_p0:
        dc.b    $00
        dc.b    $20, $30, $40, $50, $60, $70, $80, $10
        dc.b    $20, $30, $40, $50, $60, $70, $80, $10
hmove_p1:
        dc.b    $00
        dc.b    $20, $30, $40, $50, $60, $70, $80, $10
        dc.b    $20, $30, $40, $50, $60, $70, $80, $10
