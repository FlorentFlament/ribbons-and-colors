;;; Pointer in the background table
;;; Used for the parallax effect in the background
bg_ptr = ptr0
sp0_ptr         ds.w    2
sp1_ptr         ds.w    2

sprite_cnt      ds.b    1     ; Counter to display 1 column of sprites
sp0_pos         ds.b    1     ; storage for sprite 0 fine positionning
sp1_pos         ds.b    1     ; storage for sprite 1 fine positionning

;;; Font offsets array
;;; To build the font pointers sp0_ptr and sp1_ptr
font_off0       ds.b    12      ; Offsets for sprite 0
font_off1       ds.b    12      ; Offsets for sprite 1

;;; Sprites positions
pos_arr0        ds.b    12      ; Positions array for sprite 0
pos_arr1        ds.b    12      ; Positions array for sprite 1
