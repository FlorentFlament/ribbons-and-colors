;;; Initializes fonts pointers and array
        MAC INIT_FONTS
        ;; Initialize hi byte of sp0_ptr and sp1_ptr
        lda #>text_font
        sta sp0_ptr+1
        sta sp1_ptr+1

        ;; Initializes font offets
        ldy #11
        lda #0
.font_offsets:
        clc
        adc #$10
        sta font_off0,Y
        clc
        adc #$10
        sta font_off1,Y
        dey
        bpl .font_offsets
        ENDM

;;; Initialize sprite positions
        MAC INIT_SPRITES_POSITIONS
        ldy #11
.pos_array:
        clc
        tya
        adc #30
        sta pos_arr0,Y
        clc
        tya
        eor #$ff
        adc #122
        sta pos_arr1,Y
        dey
        bpl .pos_array
        ENDM

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

        ;; Initialize font offsets
        INIT_FONTS
        INIT_SPRITES_POSITIONS
	rts

text_vblank:	SUBROUTINE
        jsr tia_player          ; Play the music

        ;; Set background pointer for parallax effect
        SET_POINTER bg_ptr,bg_table
        clc
        lda frame_cnt
        lsr
        and #$0f
        adc bg_ptr
        sta bg_ptr
        lda bg_ptr+1
        adc #$00
        sta bg_ptr+1

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

        MAC SET_BG_N_SPRITES
        lda (bg_ptr),Y
        sta COLUPF
        lda (sp0_ptr),Y
        sta GRP0
        lda (sp1_ptr),Y
        sta GRP1
        ENDM

text_kernel:	SUBROUTINE
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
        ldx #11                 ; Use X for sprite counter
.column_loop:
        ;; Width is 144 pixels = 160 - 16 (2x8 borders)
        ;; First pixel for sp0_pos = #17
        ;; First out of screen pix for #161
        lda pos_arr0,X       ; Fetch sprite0 position - 8 is left edge
        sta sp0_pos
        lda pos_arr1,X    ; Fetch sprite1 position - 144 is right edge
        sta sp1_pos

.sprite_header:
        ldy #15                 ; Use Y for sprite line counter
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
        ;; First sprites line needs sp0_ptr and sp1_ptr to be set
        lda font_off0,X
        sta sp0_ptr
        lda font_off1,X
        sta sp1_ptr
        ;; As weel as HMOVE performed after WSYNC to commit sprite's
        ;; fine position
        sta WSYNC
        sta HMOVE
        SET_BG_N_SPRITES
        ;; Displaying remaining lines of sprites
        dey
.sprite_body:
        sta WSYNC
        SET_BG_N_SPRITES
        dey
        bpl .sprite_body

        dex
        bmi .end
        jmp .column_loop
.end:

        sta WSYNC
        lda #$00
        sta GRP0
        sta GRP1
        sta COLUPF
        rts

;;; Doubling the table is a trick to be able to move start pointer in
;;; the table.  It saves the otherwise required "AND #$0f"
;;; instruction.
bg_table:
        dc.b $90, $90, $92, $92, $94, $94, $96, $96
        dc.b $98, $98, $96, $96, $94, $94, $92, $92
        dc.b $90, $90, $92, $92, $94, $94, $96, $96
        dc.b $98, $98, $96, $96, $94, $94, $92, $92

sp0_table:
        dc.b $ff, $7e, $3c, $18, $18, $3c, $7e, $ff
        dc.b $ff, $7e, $3c, $18, $18, $3c, $7e, $ff

sp1_table:
        dc.b $18, $3c, $7e, $ff, $ff, $7e, $3c, $18
        dc.b $18, $3c, $7e, $ff, $ff, $7e, $3c, $18
