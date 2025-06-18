; Variables required for a single text display
; Pointer towards the text to be displayed
fx_text_idx	ds 1
fx_text_cnt	ds 1		; Counter for the text movement
fx_text_scaler  ds 1            ; Scaler to move the text at the right speed

; 12 pointers used to display the text.
; txt_buf is long to initialize so this is done during vblank and must
; not be overriden during the screen display.
; It cannot be mutualized with other FXs ont the screen.
txt_buf	        ds 12*2
