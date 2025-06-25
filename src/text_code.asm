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
        ldx line_cnt            ; Use time after setting sprites to perform computation
        stx WSYNC
        stx COLUPF
        inx
        stx line_cnt
        COARSE_POSITION_ONE_SPRITE 0
        sta WSYNC
        SET_BACKGROUND_COLOR
        COARSE_POSITION_ONE_SPRITE 1
        ;; Fine sprites position
        sta WSYNC
        SET_BACKGROUND_COLOR
        FINE_POSITION_ONE_SPRITE 0
        FINE_POSITION_ONE_SPRITE 1
        ENDM

;;; Uses A and Y registers
        MAC SET_BACKGROUND_COLOR
        lda line_cnt
        sta COLUPF
        inc line_cnt
        ENDM

text_kernel:	SUBROUTINE
        lda frame_cnt
        sta line_cnt
        lda frame_cnt+1
        ror
        tax
        lda line_cnt
        ror
        sta line_cnt
        txa
        ror
        lda line_cnt
        ror
        sta line_cnt
        eor #$ff
        sta line_cnt

        ;; Header offset
        clc
        lda frame_cnt
        and #$0f                ; in [0  , 15]
        eor #$ff                ; in [-16, -1]
        adc #$0f                ; in [-1 , 14]
        bmi .display_column
        tax
.header_loop:
        sta WSYNC
        SET_BACKGROUND_COLOR
        dex
        bpl .header_loop

.display_column:
        lda #12
        sta sprite_cnt
.column_loop:
        ;; Width is 144 pixels = 160 - 16 (2x8 borders)
        ;; First pixel for sp0_pos = #17
        ;; First out of screen pix for #161
        lda #0                 ; Fetch sprite0 position
        sta sp0_pos
        lda #113                 ; Fetch sprite1 position
        sta sp1_pos
        POSITION_BOTH_SPRITES

        lda #12
        sta sprite_it
.sprite_loop:
        sta WSYNC
        ;; (1) Trick do reduce sprites vertical spacing
        ;; by commiting horizontal moves while setting sprites pixels
        sta HMOVE

        SET_BACKGROUND_COLOR
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
        bmi .end
        jmp .column_loop
.end:


        sta WSYNC
        lda #$00
        sta GRP0
        sta GRP1
        sta COLUPF
        rts
