; TIATracker music player
; Copyright 2016 Andre "Kylearan" Wichmann
; Website: https://bitbucket.org/kylearan/tiatracker
; Email: andre.wichmann@gmx.de
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;   http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

; Song author: Glafouk
; Song name: Chloé éclot...

; @com.wudsn.ide.asm.hardware=ATARI2600

; =====================================================================
; TIATracker melodic and percussion instruments, patterns and sequencer
; data.
; =====================================================================
tt_TrackDataStart:

; =====================================================================
; Melodic instrument definitions (up to 7). tt_envelope_index_c0/1 hold
; the index values into these tables for the current instruments played
; in channel 0 and 1.
; 
; Each instrument is defined by:
; - tt_InsCtrlTable: the AUDC value
; - tt_InsADIndexes: the index of the start of the ADSR envelope as
;       defined in tt_InsFreqVolTable
; - tt_InsSustainIndexes: the index of the start of the Sustain phase
;       of the envelope
; - tt_InsReleaseIndexes: the index of the start of the Release phase
; - tt_InsFreqVolTable: The AUDF frequency and AUDV volume values of
;       the envelope
; =====================================================================

; Instrument master CTRL values
tt_InsCtrlTable:
        dc.b $06, $04, $0c, $04


; Instrument Attack/Decay start indexes into ADSR tables.
tt_InsADIndexes:
        dc.b $00, $04, $04, $13


; Instrument Sustain start indexes into ADSR tables
tt_InsSustainIndexes:
        dc.b $00, $0f, $0f, $18


; Instrument Release start indexes into ADSR tables
; Caution: Values are stored with an implicit -1 modifier! To get the
; real index, add 1.
tt_InsReleaseIndexes:
        dc.b $01, $10, $10, $19


; AUDVx and AUDFx ADSR envelope values.
; Each byte encodes the frequency and volume:
; - Bits 7..4: Freqency modifier for the current note ([-8..7]),
;       8 means no change. Bit 7 is the sign bit.
; - Bits 3..0: Volume
; Between sustain and release is one byte that is not used and
; can be any value.
; The end of the release phase is encoded by a 0.
tt_InsFreqVolTable:
; 0: ---
        dc.b $8c, $00, $8c, $00
; 1+2: ---
        dc.b $8b, $8a, $89, $88, $87, $86, $85, $84
        dc.b $83, $82, $81, $81, $00, $80, $00
; 3: ---
        dc.b $85, $84, $83, $82, $81, $80, $00, $80
        dc.b $00



; =====================================================================
; Percussion instrument definitions (up to 15)
;
; Each percussion instrument is defined by:
; - tt_PercIndexes: The index of the first percussion frame as defined
;       in tt_PercFreqTable and tt_PercCtrlVolTable
; - tt_PercFreqTable: The AUDF frequency value
; - tt_PercCtrlVolTable: The AUDV volume and AUDC values
; =====================================================================

; Indexes into percussion definitions signifying the first frame for
; each percussion in tt_PercFreqTable.
; Caution: Values are stored with an implicit +1 modifier! To get the
; real index, subtract 1.
tt_PercIndexes:
        dc.b $01, $05, $09


; The AUDF frequency values for the percussion instruments.
; If the second to last value is negative (>=128), it means it's an
; "overlay" percussion, i.e. the player fetches the next instrument note
; immediately and starts it in the sustain phase next frame. (Needs
; TT_USE_OVERLAY)
tt_PercFreqTable:
; 0: KickShort
        dc.b $05, $09, $8c, $00
; 1: HiHat
        dc.b $00, $01, $00, $00
; 2: SnareShort
        dc.b $05, $1c, $08, $02, $01, $82, $00


; The AUDCx and AUDVx volume values for the percussion instruments.
; - Bits 7..4: AUDC value
; - Bits 3..0: AUDV value
; 0 means end of percussion data.
tt_PercCtrlVolTable:
; 0: KickShort
        dc.b $6f, $6d, $69, $00
; 1: HiHat
        dc.b $84, $82, $81, $00
; 2: SnareShort
        dc.b $8f, $cf, $6e, $8b, $87, $84, $00


        
; =====================================================================
; Track definition
; The track is defined by:
; - tt_PatternX (X=0, 1, ...): Pattern definitions
; - tt_PatternPtrLo/Hi: Pointers to the tt_PatternX tables, serving
;       as index values
; - tt_SequenceTable: The order in which the patterns should be played,
;       i.e. indexes into tt_PatternPtrLo/Hi. Contains the sequences
;       for all channels and sub-tracks. The variables
;       tt_cur_pat_index_c0/1 hold an index into tt_SequenceTable for
;       each channel.
;
; So tt_SequenceTable holds indexes into tt_PatternPtrLo/Hi, which
; in turn point to pattern definitions (tt_PatternX) in which the notes
; to play are specified.
; =====================================================================

; ---------------------------------------------------------------------
; Pattern definitions, one table per pattern. tt_cur_note_index_c0/1
; hold the index values into these tables for the current pattern
; played in channel 0 and 1.
;
; A pattern is a sequence of notes (one byte per note) ending with a 0.
; A note can be either:
; - Pause: Put melodic instrument into release. Must only follow a
;       melodic instrument.
; - Hold: Continue to play last note (or silence). Default "empty" note.
; - Slide (needs TT_USE_SLIDE): Adjust frequency of last melodic note
;       by -7..+7 and keep playing it
; - Play new note with melodic instrument
; - Play new note with percussion instrument
; - End of pattern
;
; A note is defined by:
; - Bits 7..5: 1-7 means play melodic instrument 1-7 with a new note
;       and frequency in bits 4..0. If bits 7..5 are 0, bits 4..0 are
;       defined as:
;       - 0: End of pattern
;       - [1..15]: Slide -7..+7 (needs TT_USE_SLIDE)
;       - 8: Hold
;       - 16: Pause
;       - [17..31]: Play percussion instrument 1..15
;
; The tracker must ensure that a pause only follows a melodic
; instrument or a hold/slide.
; ---------------------------------------------------------------------
TT_FREQ_MASK    = %00011111
TT_INS_HOLD     = 8
TT_INS_PAUSE    = 16
TT_FIRST_PERC   = 17

; b0a
tt_pattern0:
        dc.b $35, $08, $08, $08, $10, $08, $08, $08
        dc.b $08, $08, $35, $08, $10, $08, $35, $08
        dc.b $08, $08, $10, $08, $08, $08, $35, $08
        dc.b $10, $08, $35, $08, $08, $08, $10, $08
        dc.b $39, $08, $08, $08, $08, $08, $10, $08
        dc.b $39, $08, $08, $08, $10, $08, $39, $08
        dc.b $08, $08, $08, $08, $10, $08, $39, $08
        dc.b $08, $08, $39, $08, $10, $08, $39, $08
        dc.b $00

; b0b
tt_pattern1:
        dc.b $2f, $08, $08, $08, $10, $08, $08, $08
        dc.b $08, $08, $08, $08, $2f, $08, $08, $08
        dc.b $10, $08, $2f, $08, $10, $08, $2f, $08
        dc.b $10, $08, $08, $08, $2f, $08, $08, $08
        dc.b $30, $08, $08, $08, $10, $08, $08, $08
        dc.b $08, $08, $30, $08, $10, $08, $08, $08
        dc.b $30, $08, $10, $08, $08, $08, $30, $08
        dc.b $10, $08, $30, $08, $10, $08, $30, $08
        dc.b $00

; b0a+mel0a
tt_pattern2:
        dc.b $35, $08, $08, $08, $5b, $08, $6a, $08
        dc.b $5b, $08, $35, $08, $08, $08, $08, $08
        dc.b $58, $08, $35, $08, $5b, $08, $35, $08
        dc.b $6a, $08, $35, $08, $08, $08, $5b, $08
        dc.b $00

; b0a+mel0b
tt_pattern3:
        dc.b $39, $08, $08, $08, $7b, $08, $7b, $08
        dc.b $39, $08, $08, $08, $78, $08, $39, $08
        dc.b $78, $08, $75, $08, $78, $08, $39, $08
        dc.b $7b, $08, $39, $08, $78, $08, $39, $08
        dc.b $00

; b0b+mel0c
tt_pattern4:
        dc.b $2f, $08, $08, $08, $6d, $08, $6a, $08
        dc.b $72, $08, $70, $08, $2f, $08, $08, $08
        dc.b $6d, $08, $2f, $08, $70, $08, $2f, $08
        dc.b $72, $08, $70, $08, $2f, $08, $08, $08
        dc.b $00

; b0b+mel0d
tt_pattern5:
        dc.b $30, $08, $08, $08, $6d, $08, $6d, $08
        dc.b $6d, $08, $30, $08, $5b, $08, $58, $08
        dc.b $30, $08, $5b, $08, $6a, $08, $30, $08
        dc.b $5b, $08, $30, $08, $6a, $08, $30, $08
        dc.b $00

; b0a+mel0bAlt
tt_pattern6:
        dc.b $39, $08, $08, $08, $7b, $08, $78, $08
        dc.b $39, $08, $08, $08, $75, $08, $39, $08
        dc.b $72, $08, $75, $08, $78, $08, $39, $08
        dc.b $78, $08, $39, $08, $75, $08, $39, $08
        dc.b $00

; b0b+mel0dAlt
tt_pattern7:
        dc.b $30, $08, $08, $08, $70, $08, $6e, $08
        dc.b $6d, $08, $30, $08, $6a, $08, $5b, $08
        dc.b $30, $08, $6a, $08, $6d, $08, $30, $08
        dc.b $5b, $08, $30, $08, $58, $08, $30, $08
        dc.b $00

; b0a+mel1a
tt_pattern8:
        dc.b $35, $08, $72, $08, $70, $08, $5b, $08
        dc.b $6d, $08, $35, $08, $6a, $08, $35, $08
        dc.b $70, $08, $6d, $08, $72, $08, $35, $08
        dc.b $70, $08, $35, $08, $72, $08, $70, $08
        dc.b $39, $08, $72, $08, $6d, $08, $6a, $08
        dc.b $39, $08, $72, $08, $5b, $08, $39, $08
        dc.b $6a, $08, $6d, $08, $6a, $08, $39, $08
        dc.b $5f, $08, $39, $08, $6a, $08, $39, $08
        dc.b $00

; b0b+mel1b
tt_pattern9:
        dc.b $2f, $08, $08, $08, $72, $08, $6d, $08
        dc.b $70, $08, $72, $08, $2f, $08, $75, $08
        dc.b $74, $08, $2f, $08, $72, $08, $2f, $08
        dc.b $6a, $08, $6d, $08, $2f, $08, $70, $08
        dc.b $30, $08, $72, $08, $70, $08, $6d, $08
        dc.b $70, $08, $30, $08, $6a, $08, $08, $08
        dc.b $30, $08, $5f, $08, $5f, $08, $30, $08
        dc.b $6a, $08, $30, $08, $5b, $08, $30, $08
        dc.b $00

; b0b+mel1c
tt_pattern10:
        dc.b $2f, $08, $08, $08, $72, $08, $70, $08
        dc.b $6a, $08, $72, $08, $2f, $08, $75, $08
        dc.b $74, $08, $2f, $08, $72, $08, $2f, $08
        dc.b $6a, $08, $6d, $08, $2f, $08, $70, $08
        dc.b $30, $08, $72, $08, $6d, $08, $72, $08
        dc.b $74, $08, $30, $08, $70, $08, $6d, $08
        dc.b $30, $08, $5b, $08, $5b, $08, $30, $08
        dc.b $6a, $08, $30, $08, $58, $08, $30, $08
        dc.b $00

; b0a+mel2a
tt_pattern11:
        dc.b $35, $08, $08, $08, $7b, $08, $78, $08
        dc.b $08, $08, $35, $08, $7b, $08, $35, $08
        dc.b $75, $08, $75, $08, $78, $08, $35, $08
        dc.b $7b, $08, $35, $08, $08, $08, $78, $08
        dc.b $39, $08, $08, $08, $7b, $08, $72, $08
        dc.b $39, $08, $08, $08, $75, $08, $39, $08
        dc.b $78, $08, $7b, $08, $7b, $08, $39, $08
        dc.b $78, $08, $39, $08, $70, $08, $39, $08
        dc.b $00

; b0b+mel2b
tt_pattern12:
        dc.b $2f, $08, $08, $08, $74, $08, $74, $08
        dc.b $75, $08, $7b, $08, $2f, $08, $08, $08
        dc.b $78, $08, $2f, $08, $7b, $08, $2f, $08
        dc.b $78, $08, $75, $08, $2f, $08, $7b, $08
        dc.b $30, $08, $08, $08, $7b, $08, $08, $08
        dc.b $78, $08, $30, $08, $75, $08, $70, $08
        dc.b $30, $08, $72, $08, $75, $08, $30, $08
        dc.b $78, $08, $30, $08, $75, $08, $30, $08
        dc.b $00

; b0b+mel2c
tt_pattern13:
        dc.b $2f, $08, $08, $08, $75, $08, $74, $08
        dc.b $75, $08, $7b, $08, $2f, $08, $08, $08
        dc.b $78, $08, $2f, $08, $74, $08, $2f, $08
        dc.b $75, $08, $7b, $08, $2f, $08, $7b, $08
        dc.b $30, $08, $08, $08, $7b, $08, $08, $08
        dc.b $78, $08, $30, $08, $75, $08, $70, $08
        dc.b $30, $08, $6d, $08, $75, $08, $30, $08
        dc.b $70, $08, $30, $08, $6d, $08, $30, $08
        dc.b $00

; d0
tt_pattern14:
        dc.b $11, $08, $08, $08, $12, $08, $08, $08
        dc.b $13, $08, $08, $08, $12, $08, $08, $08
        dc.b $11, $08, $08, $08, $12, $08, $08, $08
        dc.b $13, $08, $08, $08, $12, $08, $08, $08
        dc.b $11, $08, $08, $08, $12, $08, $08, $08
        dc.b $13, $08, $08, $08, $12, $08, $08, $08
        dc.b $11, $08, $08, $08, $12, $08, $08, $08
        dc.b $00

; d0FinA
tt_pattern15:
        dc.b $13, $08, $08, $08, $11, $08, $11, $08
        dc.b $00

; d0FinB
tt_pattern16:
        dc.b $13, $08, $08, $08, $13, $08, $13, $08
        dc.b $00

; d0FinC
tt_pattern17:
        dc.b $13, $08, $13, $08, $13, $08, $13, $08
        dc.b $00

; d+mel0
tt_pattern18:
        dc.b $11, $8d, $98, $4d, $12, $50, $94, $8d
        dc.b $13, $08, $92, $08, $12, $08, $90, $54
        dc.b $11, $90, $8d, $08, $12, $52, $90, $8d
        dc.b $13, $08, $92, $50, $12, $4d, $94, $08
        dc.b $11, $08, $98, $92, $12, $50, $94, $08
        dc.b $13, $08, $92, $52, $12, $08, $90, $08
        dc.b $11, $8f, $8d, $52, $12, $52, $90, $08
        dc.b $00

; d+mel0FinA
tt_pattern19:
        dc.b $13, $08, $92, $54, $11, $58, $11, $08
        dc.b $00

; d+mel0FinB
tt_pattern20:
        dc.b $13, $08, $92, $54, $13, $58, $13, $08
        dc.b $00

; d+mel0FinC
tt_pattern21:
        dc.b $13, $08, $13, $08, $13, $52, $13, $08
        dc.b $00

; HH+mel0
tt_pattern22:
        dc.b $08, $8d, $98, $4d, $12, $50, $94, $8d
        dc.b $08, $08, $92, $08, $12, $08, $90, $54
        dc.b $08, $90, $8d, $08, $12, $52, $90, $8d
        dc.b $08, $08, $92, $50, $12, $4d, $94, $08
        dc.b $08, $08, $98, $92, $12, $50, $94, $08
        dc.b $08, $08, $92, $52, $12, $08, $90, $08
        dc.b $08, $8f, $8d, $52, $12, $52, $90, $08
        dc.b $00

; HH+mel0FinA
tt_pattern23:
        dc.b $08, $8d, $90, $54, $12, $12, $12, $12
        dc.b $00

; HH+mel0FinB
tt_pattern24:
        dc.b $08, $8d, $90, $54, $13, $08, $13, $08
        dc.b $00




; Individual pattern speeds (needs TT_GLOBAL_SPEED = 0).
; Each byte encodes the speed of one pattern in the order
; of the tt_PatternPtr tables below.
; If TT_USE_FUNKTEMPO is 1, then the low nibble encodes
; the even speed and the high nibble the odd speed.
    IF TT_GLOBAL_SPEED = 0
tt_PatternSpeeds:
%%PATTERNSPEEDS%%
    ENDIF


; ---------------------------------------------------------------------
; Pattern pointers look-up table.
; ---------------------------------------------------------------------
tt_PatternPtrLo:
        dc.b <tt_pattern0, <tt_pattern1, <tt_pattern2, <tt_pattern3
        dc.b <tt_pattern4, <tt_pattern5, <tt_pattern6, <tt_pattern7
        dc.b <tt_pattern8, <tt_pattern9, <tt_pattern10, <tt_pattern11
        dc.b <tt_pattern12, <tt_pattern13, <tt_pattern14, <tt_pattern15
        dc.b <tt_pattern16, <tt_pattern17, <tt_pattern18, <tt_pattern19
        dc.b <tt_pattern20, <tt_pattern21, <tt_pattern22, <tt_pattern23
        dc.b <tt_pattern24
tt_PatternPtrHi:
        dc.b >tt_pattern0, >tt_pattern1, >tt_pattern2, >tt_pattern3
        dc.b >tt_pattern4, >tt_pattern5, >tt_pattern6, >tt_pattern7
        dc.b >tt_pattern8, >tt_pattern9, >tt_pattern10, >tt_pattern11
        dc.b >tt_pattern12, >tt_pattern13, >tt_pattern14, >tt_pattern15
        dc.b >tt_pattern16, >tt_pattern17, >tt_pattern18, >tt_pattern19
        dc.b >tt_pattern20, >tt_pattern21, >tt_pattern22, >tt_pattern23
        dc.b >tt_pattern24        


; ---------------------------------------------------------------------
; Pattern sequence table. Each byte is an index into the
; tt_PatternPtrLo/Hi tables where the pointers to the pattern
; definitions can be found. When a pattern has been played completely,
; the next byte from this table is used to get the address of the next
; pattern to play. tt_cur_pat_index_c0/1 hold the current index values
; into this table for channels 0 and 1.
; If TT_USE_GOTO is used, a value >=128 denotes a goto to the pattern
; number encoded in bits 6..0 (i.e. value AND %01111111).
; ---------------------------------------------------------------------
tt_SequenceTable:
        ; ---------- Channel 0 ----------
        dc.b $00, $01, $00, $01, $00, $01, $00, $01
        dc.b $02, $03, $04, $05, $02, $06, $04, $07
        dc.b $08, $09, $08, $0a, $02, $03, $04, $05
        dc.b $02, $06, $04, $07, $0b, $0c, $0b, $0d
        dc.b $02, $03, $04, $05, $02, $06, $04, $07
        dc.b $80

        
        ; ---------- Channel 1 ----------
        dc.b $0e, $0f, $0e, $10, $0e, $0f, $0e, $11
        dc.b $12, $13, $12, $14, $12, $13, $12, $15
        dc.b $12, $13, $12, $14, $12, $13, $12, $15
        dc.b $12, $13, $12, $14, $12, $13, $12, $15
        dc.b $12, $13, $12, $14, $12, $13, $12, $11
        dc.b $12, $0f, $12, $14, $12, $14, $12, $15
        dc.b $16, $17, $16, $17, $16, $17, $16, $18
        dc.b $a9


        echo "Track size: ", *-tt_TrackDataStart
