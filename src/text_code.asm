;;; Takes Y in Y and K1 in A and compute a sine based on frame_cnt
;;; Uses ptr0
;;; goal is to compute K0*sin(K1 + K2*Y + K3*frame_cnt)
;;; With Kn varying (slowly) with frame_cnt
        MAC SINE_FUNCTION
        sta ptr0                ; Accumulator
        tya
        sec
        sbc div_11              ; Adjust Y according to moving characters
        REPEAT 3
        asl                     ; multiply Y by 8
        REPEND
        clc
        adc ptr0
        sta ptr0
        lda frame_cnt
        REPEAT 2
        asl                     ; multiply by 4
        REPEND
        clc
        adc ptr0
        sta ptr0
        tax
        lda sine_table,X
        ;lsr                     ; multiply by 2
        ENDM

;;; Initialize sprite positions
;;; Uses ptr0
    MAC UPDATE_SPRITES_POSITIONS
        ldy #(CHARACTERS_COUNT-1)
.pos_array:
        lda #0
        SINE_FUNCTION
        clc
        adc #40
        sta pos_arr0,Y
        lda #64
        SINE_FUNCTION
        clc
        adc #80
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
        ;; Sprites color
        lda #$ff
        sta COLUP0
        sta COLUP1

        ;; Initializes text pointers
        SET_POINTER text_ptr0, text_data0
        SET_POINTER text_ptr1, text_data1

        ;; Initialize font offsets
        lda #>text_font
        sta sp0_ptr+1
        sta sp1_ptr+1

        ;; 11 (TOTAL_SPRITE_HEIGHT) related counters
        lda #(TOTAL_SPRITE_HEIGHT-1)
        sta mod_11
        asl
        sta mod_22
        lda #$00
        sta div_11
	rts

;;; Move the background pointer in the background buffer; For the
;;; parallax effect.
;;; Uses A register, and ptr0
bg_offset = ptr0
    MAC UPDATE_BACKGROUND_POINTER
        ;; Compute bg_offset
        lda mod_22
        lsr
        sta bg_offset
        eor #$ff
        clc
        adc #TOTAL_SPRITE_HEIGHT ; TOTAL_SPRITE_HEIGHT - bg_offset
        clc
        adc #<bg_table
        sta bg_ptr
        lda #>bg_table
        adc #$00
        sta bg_ptr+1
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

;;; argument 0 or 1 indicates which text stream
    MAC UPDATE_FIRST_CHARACTER
        ldy #$00
        lda (text_ptr{1}),Y
        tay                     ; Save character for later use
        REPEAT 3
        asl
        REPEND
        sta font_ptr{1}         ; Store updated font pointer

        tya                     ; Recall fetched character
        beq .rewind_pointer
        ;; Increment text pointer for next use
        clc
        lda text_ptr{1}
        adc #$01
        sta text_ptr{1}
        lda text_ptr{1}+1
        adc #$00
        sta text_ptr{1}+1
        jmp .end
.rewind_pointer:
        SET_POINTER text_ptr{1},text_data{1}
.end:
     ENDM

;;; Round rotate charactes and positions
    MAC UPDATE_CHARACTERS
        ;; Rotate font pointers
        ROTATE_ARRAY font_ptr0
        ROTATE_ARRAY font_ptr1

        ;; And add new character at the beginning of the arrays
        UPDATE_FIRST_CHARACTER 0
        UPDATE_FIRST_CHARACTER 1

        ;; Update characters positions
        ROUND_ROTATE_ARRAY pos_arr0
        ROUND_ROTATE_ARRAY pos_arr1
    ENDM

text_vblank:	SUBROUTINE
        jsr tia_player            ; Play the music
        UPDATE_BACKGROUND_POINTER ; Used for parallax

        ;; Fetch new character every 11 frames
        lda mod_11
        cmp #(TOTAL_SPRITE_HEIGHT-1)
        bne .skip_rotate
        UPDATE_CHARACTERS
.skip_rotate:

        UPDATE_SPRITES_POSITIONS
	rts

text_overscan:  SUBROUTINE
        dec mod_22
        bpl .mod_22_positive
        lda #(2*TOTAL_SPRITE_HEIGHT - 1)
        sta mod_22
.mod_22_positive:

        dec mod_11
        bpl .mod_11_positive
        lda #(TOTAL_SPRITE_HEIGHT-1) ; That's 10
        sta mod_11
        inc div_11
.mod_11_positive:
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

    MAC DRAW_BORDER_TOP
        ;; No playfield mirror
        lda #$00
        sta CTRLPF
        ldy #(BORDER_HEIGHT-2)
.border_loop:
        lda border_top_bgcols,Y
        ldx border_top_pfcols,Y
        sta WSYNC
        sta COLUBK
        stx COLUPF
        lda border_top_pf0,Y
        sta PF0
        lda border_top_pf1,Y
        sta PF1
        lda border_top_pf2,Y
        sta PF2
        lda border_top_pf3,Y
        sta PF0
        lda border_top_pf4,Y
        sta PF1
        lda border_top_pf5,Y
        sta PF2
        dey
        bne .border_loop        ; Trick last line performed outside loop

        ;; For last border line, prepare setup for main zone while
        ;; drawing background on the playfield.
        lda #$01
        sta CTRLPF              ; Playfield becomes mirror
        lda #$00
        ldx border_top_bgcols,Y
        sta WSYNC
        sta COLUBK
        stx COLUPF              ; Same color on playfield
        ;; Prepare playfield to hide HMOVE artifact
        lda #$cf
        sta PF0
        lda #$ff
        sta PF1
        sta PF2
    ENDM

    MAC DRAW_BORDER_BOTTOM
        ;; Do first line separately just drawing background and setting things
        ;; No playfield mirror
        ldy #(BORDER_HEIGHT-1)
        lda border_bottom_bgcols,Y
        sta WSYNC
        sta COLUBK
        sta COLUPF              ; Same color so we can do what we want with PF
        lda #$00                ; Clear sprites
        sta GRP0
        sta GRP1
        sta CTRLPF              ; No more playfield mirror

        dey
.border_loop:
        lda border_bottom_bgcols,Y
        ldx border_bottom_pfcols,Y
        sta WSYNC
        sta COLUBK
        stx COLUPF
        lda border_bottom_pf0,Y
        sta PF0
        lda border_bottom_pf1,Y
        sta PF1
        lda border_bottom_pf2,Y
        sta PF2
        lda border_bottom_pf3,Y
        sta PF0
        lda border_bottom_pf4,Y
        sta PF1
        lda border_bottom_pf5,Y
        sta PF2
        dey
        bpl .border_loop        ; Trick last line performed outside loop
    ENDM

text_kernel:	SUBROUTINE
        DRAW_BORDER_TOP

;;; Drawing variable height header - to create movement
        ldy mod_11
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
        cpy mod_11
        beq .skip_footer
.footer_loop:
        lda (bg_ptr),Y
        sta WSYNC
        sta COLUPF
        lda #$00
        sta GRP0
        sta GRP1
        dey
        cpy mod_11
        bne .footer_loop
.skip_footer:

        ;; Clear sprites as well
        DRAW_BORDER_BOTTOM

        ;; Clear payfield and background
        sta WSYNC
        lda #$00
        sta COLUPF
        sta COLUBK
        rts

;;; Doubling the table is a trick to be able to move start pointer in
;;; the table; and then use Y to access elements.
bg_table:
        dc.b $90, $92, $92, $94, $94, $96, $96, $94
        dc.b $94, $92, $92, $90, $92, $92, $94, $94
        dc.b $96, $96, $94, $94, $92, $92

sine_table:
	dc.b $0f, $10, $10, $11, $11, $11, $12, $12
	dc.b $13, $13, $13, $14, $14, $14, $15, $15
	dc.b $16, $16, $16, $17, $17, $17, $18, $18
	dc.b $18, $19, $19, $19, $1a, $1a, $1a, $1b
	dc.b $1b, $1b, $1b, $1c, $1c, $1c, $1c, $1d
	dc.b $1d, $1d, $1d, $1d, $1e, $1e, $1e, $1e
	dc.b $1e, $1e, $1f, $1f, $1f, $1f, $1f, $1f
	dc.b $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f
	dc.b $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f
	dc.b $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1e
	dc.b $1e, $1e, $1e, $1e, $1e, $1d, $1d, $1d
	dc.b $1d, $1d, $1c, $1c, $1c, $1c, $1b, $1b
	dc.b $1b, $1b, $1a, $1a, $1a, $19, $19, $19
	dc.b $18, $18, $18, $17, $17, $17, $16, $16
	dc.b $16, $15, $15, $14, $14, $14, $13, $13
	dc.b $13, $12, $12, $11, $11, $11, $10, $10
	dc.b $0f, $0f, $0f, $0e, $0e, $0e, $0d, $0d
	dc.b $0c, $0c, $0c, $0b, $0b, $0a, $0a, $0a
	dc.b $09, $09, $09, $08, $08, $08, $07, $07
	dc.b $07, $06, $06, $06, $05, $05, $05, $04
	dc.b $04, $04, $04, $03, $03, $03, $03, $02
	dc.b $02, $02, $02, $02, $01, $01, $01, $01
	dc.b $01, $01, $00, $00, $00, $00, $00, $00
	dc.b $00, $00, $00, $00, $00, $00, $00, $00
	dc.b $00, $00, $00, $00, $00, $00, $00, $00
	dc.b $00, $00, $00, $00, $00, $00, $00, $01
	dc.b $01, $01, $01, $01, $01, $02, $02, $02
	dc.b $02, $02, $03, $03, $03, $03, $04, $04
	dc.b $04, $04, $05, $05, $05, $06, $06, $06
	dc.b $07, $07, $07, $08, $08, $08, $09, $09
	dc.b $09, $0a, $0a, $0a, $0b, $0b, $0c, $0c
	dc.b $0c, $0d, $0d, $0e, $0e, $0e, $0f, $0f
