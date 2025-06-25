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
	rts

text_overscan:  SUBROUTINE
        rts

;; Position Sprites according to sp0_pos and sp1_pos
        ;; sp0_pos and sp1_ops respectively contain sprite0 and sprite1 positions

sp0_pos = ptr1
sp1_pos = ptr1 + 1
;;; Macro argument is 0 or 1, the sprite to position
;;; This consumes a display line
        MAC COARSE_POSITION_ONE_SPRITE
        ;; Clear sprites there to avoid wasting a scanline
        lda #$00
        sta GRP0
        sta GRP1
        ;; Set carry for subsequent substrations
        sec

        ;; Coarse positioning
        lda sp{1}_pos
        ;; coarse loop consumes 15 pixels (3 * 5cycles)
.coarse_loop:
        sbc #$0f
        bcs .coarse_loop
        sta RESP{1}
        sta sp{1}_pos           ; Save remaining pixels for fine move
        ENDM

        MAC FINE_POSITION_ONE_SPRITE
        lda sp{1}_pos
        eor #$ff
        sec
        sbc #$08
        REPEAT 4
        asl
        REPEND
        sta HMP{1}
        ENDM

;;; Position the 2 VCS sprites
;;; sp0_pos and sp1_pos contain their respective positions
;;; Consumes 2 display lines
;;; WSYNC and HMOVE need to be performed after that
        MAC POSITION_BOTH_SPRITES
        ;; Coarse positioning
        sta WSYNC
        COARSE_POSITION_ONE_SPRITE 0
        sta WSYNC
        COARSE_POSITION_ONE_SPRITE 1
        ;; Fine sprites position
        sta WSYNC
        FINE_POSITION_ONE_SPRITE 0
        FINE_POSITION_ONE_SPRITE 1
        ENDM

sprite_it  = ptr0
sprite_cnt = ptr0 + 1
text_kernel:	SUBROUTINE
        ;; Header offset
        clc
        lda frame_cnt
        and #$0f                ; in [0  , 15]
        eor #$ff                ; in [-16, -1]
        adc #$0f                ; in [-1 , 14]
        tax
        bmi .display_column
.header_loop:
        sta WSYNC
        dex
        bpl .header_loop

.display_column:
        ldx #12
        stx sprite_cnt
.column_loop:
        ;; Width is 144 pixels = 160 - 16 (2x8 borders)
        ;; First pixel for sp0_pos = #17
        ;; First out of screen pix for #161
        ldx #17+36-4            ; Fetch sprite0 position
        stx sp0_pos
        ldx #17+3*36-4          ; Fetch sprite1 position
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
