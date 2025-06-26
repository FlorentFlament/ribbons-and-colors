;;; Pointer in the background table
;;; Used for the parallax effect in the background
bg_ptr = ptr0
sp0_ptr         ds.w    1
sp1_ptr         ds.w    1

sprite_cnt      ds.b    1     ; Counter to display 1 column of sprites
sp0_pos         ds.b    1     ; storage for sprite 0 fine positionning
sp1_pos         ds.b    1     ; storage for sprite 1 fine positionning
hdr_height      ds.b    1     ; Header height

;;; Font offsets array oo build the font pointers sp0_ptr and sp1_ptr
font_off0       ds.b    CHARACTERS_COUNT ; Offsets for sprite 0
font_off1       ds.b    CHARACTERS_COUNT ; Offsets for sprite 1

;;; Sprites positions
pos_arr0        ds.b    CHARACTERS_COUNT ; Positions array for sprite 0
pos_arr1        ds.b    CHARACTERS_COUNT ; Positions array for sprite 1
