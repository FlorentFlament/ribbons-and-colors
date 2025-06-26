dummy  = ptr0               ; Counter to display 1 sprite
sprite_cnt = ptr0 + 1           ; Counter to display 1 column of sprites

sp0_pos         ds.b    1               ; storage for sprite 0 fine positionning
sp1_pos         ds.b    1               ; storage for sprite 1 fine positionning
line_cnt        ds.b    1

bg_ptr          ds.w    2
sp0_ptr         ds.w    2
sp1_ptr         ds.w    2
