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

; Song author: glafouk
; Song name: glafouk

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
        dc.b $04, $0c, $0c, $01


; Instrument Attack/Decay start indexes into ADSR tables.
tt_InsADIndexes:
        dc.b $00, $00, $0a, $10


; Instrument Sustain start indexes into ADSR tables
tt_InsSustainIndexes:
        dc.b $06, $06, $0c, $11


; Instrument Release start indexes into ADSR tables
; Caution: Values are stored with an implicit -1 modifier! To get the
; real index, add 1.
tt_InsReleaseIndexes:
        dc.b $07, $07, $0d, $12


; AUDVx and AUDFx ADSR envelope values.
; Each byte encodes the frequency and volume:
; - Bits 7..4: Freqency modifier for the current note ([-8..7]),
;       8 means no change. Bit 7 is the sign bit.
; - Bits 3..0: Volume
; Between sustain and release is one byte that is not used and
; can be any value.
; The end of the release phase is encoded by a 0.
tt_InsFreqVolTable:
; 0+1: ---
        dc.b $88, $85, $82, $85, $82, $84, $82, $00
        dc.b $80, $00
; 2: ---
        dc.b $8d, $8d, $87, $00, $80, $00
; 3: ---
        dc.b $84, $84, $00, $84, $00



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
        dc.b $01, $06, $0a


; The AUDF frequency values for the percussion instruments.
; If the second to last value is negative (>=128), it means it's an
; "overlay" percussion, i.e. the player fetches the next instrument note
; immediately and starts it in the sustain phase next frame. (Needs
; TT_USE_OVERLAY)
tt_PercFreqTable:
; 0: SheShe
        dc.b $00, $02, $02, $00, $00
; 1: KickShort
        dc.b $05, $09, $0c, $00
; 2: SnareShort
        dc.b $05, $1c, $08, $02, $01, $02, $00


; The AUDCx and AUDVx volume values for the percussion instruments.
; - Bits 7..4: AUDC value
; - Bits 3..0: AUDV value
; 0 means end of percussion data.
tt_PercCtrlVolTable:
; 0: SheShe
        dc.b $85, $84, $83, $82, $00
; 1: KickShort
        dc.b $6f, $6d, $69, $00
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

; rm0a
tt_pattern0:
        dc.b $4e, $08, $10, $08, $4e, $08, $7d, $08
        dc.b $10, $08, $4e, $08, $78, $08, $50, $08
        dc.b $7d, $08, $50, $08, $10, $08, $50, $08
        dc.b $50, $08, $10, $08, $50, $08, $10, $08
        dc.b $00

; rm0b
tt_pattern1:
        dc.b $4e, $08, $10, $08, $4e, $08, $75, $08
        dc.b $10, $08, $4e, $08, $7d, $08, $53, $08
        dc.b $7d, $08, $53, $08, $78, $08, $53, $08
        dc.b $53, $08, $10, $08, $50, $08, $4f, $08
        dc.b $00

; rm0c
tt_pattern2:
        dc.b $4e, $08, $10, $08, $4e, $08, $75, $08
        dc.b $10, $08, $4e, $08, $7d, $08, $3d, $08
        dc.b $7d, $08, $4a, $08, $78, $08, $4e, $08
        dc.b $4a, $08, $7d, $08, $50, $08, $4f, $08
        dc.b $00

; rm0d
tt_pattern3:
        dc.b $4e, $08, $10, $08, $4e, $08, $75, $08
        dc.b $10, $08, $4e, $08, $7d, $08, $3d, $08
        dc.b $7d, $08, $38, $08, $78, $08, $4a, $08
        dc.b $3d, $08, $7d, $08, $50, $08, $4f, $08
        dc.b $00

; rm+bass0a
tt_pattern4:
        dc.b $4e, $08, $97, $08, $4e, $08, $7d, $08
        dc.b $97, $08, $4e, $08, $78, $08, $50, $08
        dc.b $7d, $08, $50, $08, $93, $08, $50, $08
        dc.b $50, $08, $9a, $08, $50, $08, $9a, $08
        dc.b $00

; rm+bass0b
tt_pattern5:
        dc.b $4e, $08, $97, $08, $4e, $08, $75, $08
        dc.b $97, $08, $4e, $08, $7d, $08, $53, $08
        dc.b $8f, $08, $53, $08, $91, $08, $53, $08
        dc.b $53, $08, $97, $08, $50, $08, $4f, $08
        dc.b $00

; rm+bass0c
tt_pattern6:
        dc.b $4e, $08, $93, $08, $4e, $08, $75, $08
        dc.b $93, $08, $4e, $08, $7d, $08, $3d, $08
        dc.b $91, $08, $4a, $08, $78, $08, $4e, $08
        dc.b $4a, $08, $97, $08, $50, $08, $4f, $08
        dc.b $00

; rm+bass0d
tt_pattern7:
        dc.b $4e, $08, $91, $08, $4e, $08, $75, $08
        dc.b $91, $08, $4e, $08, $7d, $08, $3d, $08
        dc.b $97, $08, $38, $08, $78, $08, $4a, $08
        dc.b $3d, $08, $93, $08, $50, $08, $4f, $08
        dc.b $00

; drum0a
tt_pattern8:
        dc.b $08, $08, $08, $08, $11, $08, $11, $08
        dc.b $08, $08, $08, $08, $11, $08, $11, $08
        dc.b $08, $08, $08, $08, $11, $08, $11, $08
        dc.b $08, $08, $11, $11, $11, $08, $11, $08
        dc.b $00

; drum0b
tt_pattern9:
        dc.b $12, $08, $08, $08, $11, $08, $11, $08
        dc.b $08, $08, $08, $08, $11, $08, $11, $08
        dc.b $08, $08, $08, $08, $11, $08, $11, $08
        dc.b $08, $08, $11, $11, $11, $08, $12, $08
        dc.b $00

; drum0c
tt_pattern10:
        dc.b $12, $08, $08, $08, $11, $08, $12, $08
        dc.b $12, $08, $08, $08, $11, $08, $11, $08
        dc.b $12, $08, $08, $08, $11, $08, $12, $08
        dc.b $12, $08, $11, $11, $11, $08, $12, $08
        dc.b $00

; drum0d
tt_pattern11:
        dc.b $12, $08, $08, $08, $11, $08, $12, $08
        dc.b $12, $08, $08, $08, $13, $08, $11, $08
        dc.b $12, $08, $08, $08, $11, $08, $12, $08
        dc.b $12, $08, $11, $11, $13, $08, $12, $08
        dc.b $00

; drum0e
tt_pattern12:
        dc.b $12, $08, $08, $08, $11, $08, $12, $08
        dc.b $12, $08, $08, $08, $13, $08, $11, $08
        dc.b $12, $08, $08, $08, $11, $08, $12, $08
        dc.b $12, $08, $11, $11, $13, $08, $13, $08
        dc.b $00

; drum+mel0a
tt_pattern13:
        dc.b $12, $08, $2e, $08, $30, $08, $12, $08
        dc.b $12, $08, $35, $08, $13, $08, $32, $08
        dc.b $12, $08, $3d, $08, $38, $08, $12, $08
        dc.b $12, $08, $4a, $08, $13, $08, $3d, $08
        dc.b $12, $08, $32, $08, $30, $08, $12, $08
        dc.b $12, $08, $32, $08, $13, $08, $2e, $08
        dc.b $12, $08, $38, $08, $35, $08, $12, $08
        dc.b $12, $08, $32, $08, $13, $08, $3d, $08
        dc.b $00

; drum+mel0b
tt_pattern14:
        dc.b $12, $08, $2e, $08, $2a, $08, $12, $08
        dc.b $12, $08, $30, $08, $13, $08, $2e, $08
        dc.b $12, $08, $38, $08, $35, $08, $12, $08
        dc.b $12, $08, $3d, $08, $13, $08, $35, $08
        dc.b $12, $08, $32, $08, $35, $08, $12, $08
        dc.b $12, $08, $32, $08, $13, $08, $30, $08
        dc.b $12, $08, $38, $08, $35, $08, $12, $08
        dc.b $12, $08, $32, $08, $13, $08, $3d, $08
        dc.b $00

; drum+mel0c
tt_pattern15:
        dc.b $12, $08, $2e, $08, $2a, $08, $12, $08
        dc.b $12, $08, $2e, $08, $13, $08, $32, $08
        dc.b $12, $08, $30, $08, $2e, $08, $12, $08
        dc.b $12, $08, $30, $08, $13, $08, $35, $08
        dc.b $12, $08, $3d, $08, $38, $08, $12, $08
        dc.b $12, $08, $30, $08, $13, $08, $2e, $08
        dc.b $12, $08, $4a, $08, $35, $08, $12, $08
        dc.b $12, $08, $35, $08, $13, $08, $13, $08
        dc.b $00

; drum+mel1a
tt_pattern16:
        dc.b $12, $08, $3d, $4a, $3d, $08, $12, $38
        dc.b $12, $4a, $08, $3d, $13, $08, $38, $08
        dc.b $12, $08, $35, $08, $3d, $08, $12, $4a
        dc.b $12, $08, $38, $08, $13, $08, $3d, $08
        dc.b $12, $08, $2e, $30, $35, $08, $12, $32
        dc.b $12, $08, $30, $08, $13, $08, $2e, $08
        dc.b $12, $08, $35, $08, $35, $08, $12, $38
        dc.b $12, $08, $32, $08, $13, $08, $2e, $08
        dc.b $00

; drum+mel1b
tt_pattern17:
        dc.b $12, $08, $38, $3d, $38, $08, $12, $35
        dc.b $12, $32, $08, $3d, $13, $08, $38, $08
        dc.b $12, $08, $2e, $08, $30, $08, $12, $4a
        dc.b $12, $08, $30, $08, $13, $08, $2e, $08
        dc.b $12, $08, $30, $35, $2e, $08, $12, $35
        dc.b $12, $08, $2e, $08, $13, $08, $32, $08
        dc.b $12, $08, $38, $08, $35, $08, $12, $30
        dc.b $12, $08, $2e, $08, $13, $08, $30, $08
        dc.b $00

; drum+mel1c
tt_pattern18:
        dc.b $12, $08, $2a, $2e, $30, $08, $12, $2e
        dc.b $12, $2a, $08, $30, $13, $08, $32, $08
        dc.b $12, $08, $38, $08, $32, $08, $12, $30
        dc.b $12, $08, $38, $08, $13, $08, $3d, $08
        dc.b $12, $08, $32, $30, $2a, $08, $12, $2e
        dc.b $12, $08, $35, $08, $13, $08, $32, $08
        dc.b $12, $08, $4a, $08, $4e, $08, $12, $35
        dc.b $12, $08, $32, $08, $13, $08, $13, $08
        dc.b $00

; drum+mel2a
tt_pattern19:
        dc.b $12, $08, $38, $08, $3d, $08, $12, $08
        dc.b $12, $08, $4a, $08, $13, $08, $3d, $08
        dc.b $12, $08, $4e, $4a, $3d, $08, $12, $3d
        dc.b $12, $08, $3d, $08, $13, $08, $4a, $08
        dc.b $12, $08, $4a, $08, $4a, $08, $12, $3d
        dc.b $12, $08, $38, $08, $13, $08, $3d, $08
        dc.b $12, $08, $4e, $08, $4e, $08, $12, $4a
        dc.b $12, $08, $3d, $08, $13, $08, $4a, $08
        dc.b $00

; drum+mel2b
tt_pattern20:
        dc.b $12, $08, $38, $08, $35, $08, $12, $08
        dc.b $12, $08, $4a, $08, $13, $08, $3d, $08
        dc.b $12, $08, $3d, $4a, $38, $08, $12, $35
        dc.b $12, $08, $38, $08, $13, $08, $4a, $08
        dc.b $12, $08, $50, $08, $50, $08, $12, $3d
        dc.b $12, $08, $38, $08, $13, $08, $4a, $08
        dc.b $12, $08, $50, $08, $53, $08, $12, $08
        dc.b $12, $08, $3d, $08, $13, $08, $35, $08
        dc.b $00

; drum+mel2c
tt_pattern21:
        dc.b $12, $08, $35, $08, $2e, $08, $12, $08
        dc.b $12, $08, $30, $08, $13, $08, $35, $08
        dc.b $12, $08, $3d, $4a, $38, $08, $12, $35
        dc.b $12, $08, $38, $08, $13, $08, $4a, $08
        dc.b $12, $08, $35, $08, $35, $08, $12, $30
        dc.b $12, $08, $38, $08, $13, $08, $4a, $08
        dc.b $12, $08, $2e, $08, $30, $08, $12, $08
        dc.b $12, $08, $32, $08, $13, $08, $13, $08
        dc.b $00

; drum+mel0d
tt_pattern22:
        dc.b $5d, $08, $2e, $08, $11, $08, $11, $08
        dc.b $4a, $08, $35, $08, $11, $08, $11, $08
        dc.b $50, $08, $3d, $08, $11, $08, $11, $08
        dc.b $3d, $08, $4a, $08, $11, $08, $11, $08
        dc.b $3d, $08, $32, $08, $11, $08, $11, $08
        dc.b $4a, $08, $32, $08, $11, $08, $11, $08
        dc.b $4e, $08, $38, $08, $11, $08, $11, $08
        dc.b $38, $08, $11, $11, $11, $08, $11, $08
        dc.b $00

; drum+mel0e
tt_pattern23:
        dc.b $2e, $08, $2a, $08, $11, $08, $11, $08
        dc.b $30, $08, $2e, $08, $11, $08, $11, $08
        dc.b $38, $08, $35, $08, $11, $08, $11, $08
        dc.b $3d, $08, $35, $08, $11, $08, $11, $08
        dc.b $32, $08, $35, $08, $11, $08, $11, $08
        dc.b $32, $08, $30, $08, $11, $08, $11, $08
        dc.b $38, $08, $35, $08, $11, $08, $11, $08
        dc.b $32, $08, $11, $11, $11, $08, $11, $08
        dc.b $00

; drum+mel0f
tt_pattern24:
        dc.b $2e, $08, $2a, $08, $11, $08, $11, $08
        dc.b $2e, $08, $32, $08, $11, $08, $11, $08
        dc.b $30, $08, $2e, $08, $11, $08, $11, $08
        dc.b $30, $08, $35, $08, $11, $08, $11, $08
        dc.b $3d, $08, $38, $08, $11, $08, $11, $08
        dc.b $30, $08, $2e, $08, $11, $08, $11, $08
        dc.b $4a, $08, $35, $08, $12, $08, $12, $08
        dc.b $35, $08, $11, $08, $12, $08, $11, $08
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
        dc.b $00, $01, $00, $02, $00, $01, $00, $03
        dc.b $04, $05, $04, $06, $04, $05, $04, $07
        dc.b $04, $05, $04, $06, $04, $05, $04, $07
        dc.b $04, $05, $04, $06, $04, $05, $04, $07
        dc.b $04, $05, $04, $06, $04, $05, $04, $07
        dc.b $04, $05, $04, $06, $04, $05, $04, $07
        dc.b $04, $05, $04, $06, $00, $01, $00, $03
        dc.b $88

        
        ; ---------- Channel 1 ----------
        dc.b $08, $08, $08, $08, $09, $09, $09, $09
        dc.b $0a, $0a, $0a, $0a, $0b, $0b, $0b, $0c
        dc.b $0d, $0e, $0d, $0f, $10, $11, $10, $12
        dc.b $0d, $0e, $0d, $0f, $13, $14, $13, $15
        dc.b $16, $17, $16, $18, $c1


        echo "Track size: ", *-tt_TrackDataStart
