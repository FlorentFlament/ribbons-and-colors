        INCLUDE "timeline_code.asm"
        INCLUDE "sync_code.asm"
        INCLUDE "text_code.asm"

;;; Music player wrapper
tia_player:   
        INCLUDE "tia_player.asm"
        rts

main_init:
        jsr timeline_init
        jsr text_init
        rts
        
main_vblank:
        lda current_fx
        asl
        tay
        lda timeline_vblanks+1,Y
        pha
        lda timeline_vblanks,Y
        pha
        rts

main_kernel:
        lda current_fx
        asl
        tay
        lda timeline_kernels+1,Y
        pha
        lda timeline_kernels,Y
        pha
        rts

main_overscan:
        lda current_fx
        asl
        tay
        lda timeline_overscans+1,Y
        pha
        lda timeline_overscans,Y
        pha

        jsr timeline_overscan
        rts
