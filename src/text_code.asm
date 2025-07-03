;;; Takes Y in Y and K1 in A and compute a sine based on frame_cnt
;;; Uses ptr0+1
;;; Computing 1/(2**K0)*sin(K1 + (2**K2)*chr_ind + (2**K3)*frame_cnt) + K4
;;; ptr0 (8 bytes) - index of the character - untouched
;;; X is the FX index - untouched
;;; Uses ptr0+1
;;; Y used for internal loops
accu = ptr0+1
        MAC SINE_FUNCTION
        lda ptr0
        sec
        sbc div_11
        ldy k2,X
        beq .skip_k2_mul
.k2_mul:
        asl
        dey
        bne .k2_mul
.skip_k2_mul:
        sta accu

        lda frame_cnt
        ldy k3,X
        beq .skip_k3_mul
.k3_mul:
        asl
        dey
        bne .k3_mul
.skip_k3_mul:
        clc
        adc accu
        clc
        adc k1,X

        tay
        lda sine_table,Y
        ldy k0,X
        beq .skip_k0_mul
.k0_mul:
        lsr
        dey
        bne .k0_mul
.skip_k0_mul:
        clc
        adc k4,X
        ENDM

;;; Function sine_function
sine_function:  SUBROUTINE
        SINE_FUNCTION
        rts

;;; Initialize sprite positions
;;; Uses ptr0
;;; 2 parameters start and end
;;; for instance UPDATE_SPRITES_POSITIONS (CHARACTERS_COUNT-3),$ff
    MAC UPDATE_SPRITES_POSITIONS
        lda #{1}
        sta ptr0
.pos_array:
        ldx fx_index            ; Level of indirection
        lda fx_timeline,X
        tax
        jsr sine_function
        ldy ptr0                ; Y needs reloading
        sta pos_arr0,Y
        inx                     ; fx_index+1 for sprite 1
        jsr sine_function
        ldy ptr0
        sta pos_arr1,Y
        dey
        sty ptr0
        cpy #{2}
        bne .pos_array
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
        lda #$fe
        sta COLUP0
        lda #$fa
        sta COLUP1

        ;; Initializes text pointers
        SET_POINTER text_ptr0, text_data1
        SET_POINTER text_ptr1, text_data0

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

        lda #TRACK_PATTERN_FRAMES ; Counts 224 to 0 (never -)
        sta track_cnt
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
        SET_POINTER text_ptr{1},text_data1
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
    ENDM

text_vblank:	SUBROUTINE
        UPDATE_SPRITES_POSITIONS (CHARACTERS_COUNT-3),$ff
	rts

text_overscan:  SUBROUTINE
        ;; Play the music
        SET_POINTER banksw_ptr,tia_player
	jsr JMPBank

        ;; Manage mod_11, mod_22 and div_11 counters
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

        ;; Update FX index
        lda frame_cnt           ; Only every other frame
        and #$01
        beq .end_update_fx
        dec track_cnt
        bne .end_update_fx
        lda #TRACK_PATTERN_FRAMES ; rewind pattern counter
        sta track_cnt
        ldx fx_index
        inx
        cpx #FX_MAX_INDEX
        bmi .dont_rewind_fx
        ldx #0
.dont_rewind_fx:
        stx fx_index
.end_update_fx:

        UPDATE_BACKGROUND_POINTER ; Used for parallax
        ;; Fetch new character every 11 frames
        lda mod_11
        cmp #(TOTAL_SPRITE_HEIGHT-1)
        bne .skip_rotate
        UPDATE_CHARACTERS       ; pointers
.skip_rotate:
        UPDATE_SPRITES_POSITIONS (CHARACTERS_COUNT-1),(CHARACTERS_COUNT-3)
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

;;; Sine 1/(2**K0)*sin(K1 + (2**K2)*chr_ind + (2**K3)*frame_cnt) + K4
;;; Sine amplitude: 96 pixels
;;; Display zone starting at 8 ending at 146 - see fx 4-5
;;;            0       2      4       6       8        10       12      14
k0:
        dc.b   1,  1,  1,  1, 0,  0,  0,  0,  1,   1,   1,   1,  1,  1,  1,  1,
k1:
        dc.b   0, 32,  0, 96, 0, 64,  0, 96,  0, 128,   0, 128,  0, 64,  0, 64,
k2:
        dc.b   2,  2,  4,  4, 3,  3,  3,  3,  1,   1,   4,   4,  4,  4,  3,  3,
k3:
        dc.b   1,  1,  2,  2, 2,  2,  3,  3,  0,   0,   1,   1,  1,  1,  1,  1,
k4:
        dc.b  38, 68, 42, 64, 8, 50, 16, 42, 52,  52,  52,  52, 30, 76, 30, 76,

fx_timeline:
        dc.b  8, 10, 0, 14, 12, 2, 4, 6
