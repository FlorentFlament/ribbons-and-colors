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

text_kernel:	SUBROUTINE
        ;; Header offset
        clc
        lda frame_cnt
        and #$0f                ; in [0  , 15]
        eor #$ff                ; in [-16, -1]
        adc #$0f                ; in [-1 , 14]
        bmi .display_column
        sec                     ; Though there's necessary a carry at this point
.header_loop:
        sta WSYNC
        sbc #$01
        bpl .header_loop

.display_column:
        lda #12
        sta sprite_cnt
.column_loop:
        ;; Width is 144 pixels = 160 - 16 (2x8 borders)
        ;; First pixel for sp0_pos = #17
        ;; First out of screen pix for #161
        lda #17+36-4            ; Fetch sprite0 position
        sta sp0_pos
        lda #17+3*36-4          ; Fetch sprite1 position
        sta sp1_pos
        POSITION_BOTH_SPRITES

        lda #11
        sta sprite_it
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
