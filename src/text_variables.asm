;;; Needs be stored during the whole intro. Keeps track of scroll
;;; position, and parallax offset
text_ptr0       ds.w    1     ; Text 0 pointer
text_ptr1       ds.w    1     ; Text 1 pointer
bg_ptr          ds.w    1
fx_index        ds.b    1       ; Text FX index
track_cnt       ds.b    1       ; Track counter

;;; Cause 11 is the total sprite height (8 + 3)
div_11          ds.b    1       ; Frame counter divided by 11.
mod_11          ds.b    1       ; Frame counter modulo 11.
mod_22          ds.b    1       ; Frame counter divided by 22.

;;; Global arrays of pointer offsets pre-computed in vblank
;;; Font offsets array oo build the font pointers sp0_ptr and sp1_ptr
font_ptr0       ds.b    CHARACTERS_COUNT ; Font pointers for sprite 0
font_ptr1       ds.b    CHARACTERS_COUNT ; Font pointers for sprite 1

;;; Sprites positions
pos_arr0        ds.b    CHARACTERS_COUNT ; Positions array for sprite 0
pos_arr1        ds.b    CHARACTERS_COUNT ; Positions array for sprite 1

;;; Pointers used during the whole kernel
sp0_ptr         ds.w    1
sp1_ptr         ds.w    1
