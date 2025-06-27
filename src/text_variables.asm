;;; Pointer in the background table
;;; Used for the parallax effect in the background

;;; Needs be stored during the whole intro. Keeps track of scroll
;;; position, and parallax offset
hdr_height      ds.b    1     ; Header height
bg_offset       ds.b    1     ; Background offset - parallax effect

;;; Global arrays of pointer offsets pre-computed in vblank
;;; Font offsets array oo build the font pointers sp0_ptr and sp1_ptr
font_ptr0       ds.b    CHARACTERS_COUNT ; Font pointers for sprite 0
font_ptr1       ds.b    CHARACTERS_COUNT ; Font pointers for sprite 1

;;; Sprites positions
pos_arr0        ds.b    CHARACTERS_COUNT ; Positions array for sprite 0
pos_arr1        ds.b    CHARACTERS_COUNT ; Positions array for sprite 1

;;; Pointers used during the whole kernel
bg_ptr          ds.w    1
sp0_ptr         ds.w    1
sp1_ptr         ds.w    1
