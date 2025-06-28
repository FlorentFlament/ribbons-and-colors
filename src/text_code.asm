;;; Initializes fonts pointers and array
;;; Requires the text number 0 or 1
        MAC INIT_FONT_POINTERS
        ;; Initialize hi byte of sp0_ptr and sp1_ptr
        lda #>text_font
        sta sp{1}_ptr+1

        ;; Initializes font pointers
        ;; Uses reg A, X, Y and ptr0
cur_char = ptr0
        ldy #(CHARACTERS_COUNT-1)
.font_pointers:
        lda text{1},Y
        REPEAT 3
        asl
        REPEND
        sta cur_char
        tya
        eor #$ff
        clc
        adc #CHARACTERS_COUNT
        tax
        lda cur_char
        sta font_ptr{1},X
        dey
        bpl .font_pointers
        ENDM

;;; Initialize sprite positions
        MAC INIT_SPRITES_POSITIONS
        ldy #(CHARACTERS_COUNT-1)
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

;;; Rotate characters and positions
        MAC ROTATE_ARRAY
        ldy #(CHARACTERS_COUNT-2)
.rotate_loop:
        lda {1},Y
        sta {1}+1,Y
        dey
        bpl .rotate_loop
        ENDM

;;; Round rotate characters and positions
        MAC ROUND_ROTATE_ARRAY
        ldx {1}+CHARACTERS_COUNT-1
        ROTATE_ARRAY {1}
        stx {1}
        ENDM

;;; Round rotate charactes and positions
        MAC ROUND_ROTATE_CHARACTERS
        ROUND_ROTATE_ARRAY font_ptr0
        ROUND_ROTATE_ARRAY font_ptr1
        ROUND_ROTATE_ARRAY pos_arr0
        ROUND_ROTATE_ARRAY pos_arr1
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
        INIT_FONT_POINTERS 0
        INIT_FONT_POINTERS 1
        INIT_SPRITES_POSITIONS

        ; Start with max height without replacing character
        lda #(TOTAL_SPRITE_HEIGHT-1)
        sta hdr_height
        sta bg_offset
	rts

text_vblank:	SUBROUTINE
        jsr tia_player          ; Play the music

        ;; Compte bg_ptr from bg_table + bg_offset
        sec
        lda #(TOTAL_SPRITE_HEIGHT-1)
        sbc bg_offset
        adc #<bg_table
        sta bg_ptr
        lda #>bg_table
        adc #$00
        sta bg_ptr+1

        ;; Update bg_offset as required
        lda frame_cnt
        and #$01
        beq .end_bg_offset
        dec bg_offset
        bpl .end_bg_offset
        lda #(TOTAL_SPRITE_HEIGHT-1)
        sta bg_offset
.end_bg_offset

        ;; Update hdr_height and rotate characters as required
        dec hdr_height
        bpl .skip_rotate
        ROUND_ROTATE_CHARACTERS
        lda #(TOTAL_SPRITE_HEIGHT-1)
        sta hdr_height
.skip_rotate:
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

    MAC DRAW_BORDER
        ldy #(BORDER_HEIGHT-1)
.border_loop:
        sta WSYNC
        lda border_colors,Y
        sta COLUPF
        lda #$ff
        sta PF0
        sta PF1
        sta PF2
        dey
        bpl .border_loop
    ENDM

text_kernel:	SUBROUTINE
        DRAW_BORDER

        ;; Remove left and right most playfield to avoid hmove
        ;; artefacts
        lda #$cf
        sta PF0

;;; Drawing variable height header - to create movement
        ldy hdr_height
        dey
        bmi .skip_header
.header_loop:
        lda (bg_ptr),Y
        sta WSYNC
        sta COLUPF
        dey
        bpl .header_loop
.skip_header:

        ;; PAL picture is 228 pixel high Displaying 19 characters ->
        ;; 209 pixels + 11 padding = 220 pixels
        ldx #(CHARACTERS_COUNT-1) ; Use X for sprite counter
.column_loop:
;;; sp0_pos and sp1_pos ar used in header to position sprites
sp0_pos = ptr0
sp1_pos = ptr1
        ;; Width is 144 pixels = 160 - 16 (2x8 borders)
        ;; First pixel for sp0_pos = #17
        ;; First out of screen pix for #161
        lda pos_arr0,X       ; Fetch sprite0 position - 8 is left edge
        sta sp0_pos
        lda pos_arr1,X    ; Fetch sprite1 position - 144 is right edge
        sta sp1_pos
.sprite_header:
        ;; Y contains the line number from 10 to 0
        ldy #10                 ; 11 lines (8 chars + 3 positionning)
        lda (bg_ptr),Y
        sta WSYNC
        sta COLUPF
        COARSE_POSITION_ONE_SPRITE 0
        dey
        lda (bg_ptr),Y
        sta WSYNC
        sta COLUPF
        COARSE_POSITION_ONE_SPRITE 1
        sta WSYNC               ; Maximise possible right position
        dey
        lda (bg_ptr),Y
        sta COLUPF
        FINE_POSITION_ONE_SPRITE 0
        FINE_POSITION_ONE_SPRITE 1
;;; End of sp0_pos and sp1_pos usage

        ;; First sprites line needs sp0_ptr and sp1_ptr to be set
        lda font_ptr0,X
        sta sp0_ptr
        lda font_ptr1,X
        sta sp1_ptr

        dey                     ; y is now #12
        ;; Perform HMOVE after WSYNC to commit sprite's fine position
        ;; while drawing the first character line.
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
        bmi .end_column_loop
        jmp .column_loop
.end_column_loop:

        ldy #(TOTAL_SPRITE_HEIGHT-1)
        cpy hdr_height
        beq .skip_footer
.footer_loop:
        lda (bg_ptr),Y
        sta WSYNC
        sta COLUPF
        lda #$00
        sta GRP0
        sta GRP1
        dey
        cpy hdr_height
        bne .footer_loop
.skip_footer:

        ;; Clear Sprites
        sta WSYNC
        lda #$00
        sta GRP0
        sta GRP1

        DRAW_BORDER

        ;; Clear payfield
        sta WSYNC
        lda #$00
        sta COLUPF
        rts

;;; Doubling the table is a trick to be able to move start pointer in
;;; the table; and then use Y to access elements.
bg_table:
        dc.b $90, $92, $92, $94, $94, $96, $96, $94
        dc.b $94, $92, $92, $90, $92, $92, $94, $94
        dc.b $96, $96, $94, $94, $92, $92

border_colors:
        dc.b $22, $22, $22, $22, $24, $24, $24, $24
        dc.b $26, $26, $26, $26, $28, $28, $28, $28
        dc.b $2a, $2a, $2a, $2a, $2c, $2c, $2c, $2e
        dc.b $2e, $2e

sp0_table:
        dc.b $ff, $7e, $3c, $18, $18, $3c, $7e, $ff
        dc.b $ff, $7e, $3c, $18, $18, $3c, $7e, $ff

sp1_table:
        dc.b $18, $3c, $7e, $ff, $ff, $7e, $3c, $18
        dc.b $18, $3c, $7e, $ff, $ff, $7e, $3c, $18
