; ==============================================================================
; ProtagonistRoom - "A nice little room for our protagonist" (Bank $71)
;
; Recreates Hoyt Summers Pittman's 360-degree rotating room diorama
; (https://x.com/summerspittman/status/1263468726332030976):
;   - Seamless 8x8 Overlook Hotel carpet floating in pure #000000 black space
;   - 3x1x2h golden-blond "BOOKS | BOOKS | BOOKS" wooden bookshelf
;   - 1x3x1h floating cyan/royal-blue/white bed on 4 sienna-brown corner legs
;
; Controls:
;   - Auto-orbits 360 degrees by default (matching the tweet turntable video!)
;   - SELECT: Toggle 360-degree auto-orbit on / off
;   - L / R:  Manual 360-degree camera yaw orbit
;   - D-Pad:  Pan camera focus across the room
; ==============================================================================

.include "libSFX.i"
.include "pointers.s"
.include "CpuMacros.s"
.include "../gsu_iso/cpu_asset_loader.i"
.include "../gsu_iso/asset_source_rom.i"

.import GSU_Code
.import GSU_JOYPAD
.import GSU_AUTO_SPIN

.segment "ZEROPAGE"
VRAM_screen_select:     .res 1  ; 0 = VRAM_screen_1, 1 = VRAM_screen_2
SFX_buffer_position:    .res 1  ; 0 = left half [0..127], 1 = right half [128..255]

.segment "LORAM"
auto_spin_shadow:       .res 1  ; Mirrored into GSU_AUTO_SPIN during VBlank when GSU is idle

.segment "CODE"

Main:
        ; Copy WRAM-resident main loop and VBlank handler to LORAM
        memcpy  __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy  __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__

        ; Clear VRAM double-buffers and upload BG1 tilemap
        VRAM_memset $0000, $B000, $00
        VRAM_memcpy VRAM_tilemap, Map, (Map_end - Map)

        ; Clear initial GSU joypad state and $70:8000 half-screen buffer while bus is free
        RW_push set:a16i16
        lda     #$0000
        sta     f:GSU_JOYPAD
        lda     #$0001
        sta     f:GSU_AUTO_SPIN
        ldx     #$0000
@clr70: lda     #$0000
        sta     f:screenbuffer, x
        inx
        inx
        cpx     #screenbuffer_len
        bcc     @clr70
        RW_pull

        lda     #$01
        sta     a:auto_spin_shadow

        ; Initialize Bank-$71 host loader and stage Protagonist Room assets
        SFX_LOADER_INIT SFX_DEFAULT_GSU_SCMR
        SFX_LOAD_LEVEL ProtagonistRoomDef

        ; Ensure CGRAM[0] backdrop is pure #000000 black ($0000)
        stz     CGADD
        stz     CGDATA
        stz     CGDATA

        ; Configure GSU hardware registers (PBR=$03, ROMBR=$04, SCBR=$20, SCMR=%00011101)
        initGSU_4bpp_160

        jml     __MAIN_LOOP_RUN__

; ==============================================================================
; WRAM-Resident Main Loop (executes in LORAM while GSU owns ROM/RAM buses)
; ==============================================================================
.segment "MAIN_LOOP"
Main2:
        RW_forced a8i16
        lda     #bgmode(BG_MODE_1, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
        sta     BGMODE
        lda     #bgsc(VRAM_tilemap, SC_SIZE_32X32)
        sta     BG1SC

        lda     #bg12nba(VRAM_screen_1, 0)
        sta     BG12NBA

        lda     #tm(ON, OFF, OFF, OFF, OFF)
        sta     TM

        lda     #<(-$20)
        sta     BG1VOFS
        lda     #>(-$20)
        sta     BG1VOFS
        stz     BG1HOFS
        stz     BG1HOFS

        stz     z:VRAM_screen_select
        stz     z:SFX_buffer_position

        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     z:SFX_inidisp

        VBL_set Vblank
        gsuOn
        VBL_on

infinite_loop:
        bra     infinite_loop

; ==============================================================================
; WRAM-Resident VBlank Handler
; ==============================================================================
.segment "VBLANK"
Vblank:
        RW_forced a8i16
        lda     #$80
        pha
        plb

        lda     a:sfx_gsu_load_lock
        beq     :+
        endVBlank
:
        ; Toggle auto_spin_shadow on rising-edge SELECT press
        lda     z:SFX_joy1trig + 1
        and     #>JOY_SELECT
        beq     :+
        lda     a:auto_spin_shadow
        eor     #$01
        sta     a:auto_spin_shadow
:
        gsuRunning
        beq     :+
        endVBlank
:
        ; GSU is idle; release RAN briefly or write while GSU idle?
        ; Note: while GSU is stopped (GO=0), S-CPU can access $70 if RAN is cleared,
        ; Wait: in CampusStory, GSU_SCMR keeps RAN=1? Let's release RAN around $70 writes just to be 100% hardware-accurate!
        stz     GSU_SCMR

        RW a16
        lda     z:SFX_joy1cont
        sta     f:GSU_JOYPAD
        lda     a:auto_spin_shadow
        and     #$00FF
        sta     f:GSU_AUTO_SPIN
        RW a8

        lda     z:VRAM_screen_select
        bne     drawScreen2
        jmp     drawScreen1

drawScreen2:
        lda     z:SFX_buffer_position
        beq     @copyStart2
        VRAM_memcpy (VRAM_screen_2 + screenbuffer_len), screenbuffer, screenbuffer_len
        stz     z:SFX_buffer_position
        lda     #$00
        sta     f:GSU_FRAME_HALF
        stz     z:VRAM_screen_select
        lda     #bg12nba(VRAM_screen_2, 0)
        sta     BG12NBA
        lda     #%00011101
        sta     GSU_SCMR
        gsuOn
        endVBlank
@copyStart2:
        VRAM_memcpy VRAM_screen_2, screenbuffer, screenbuffer_len
        lda     #$01
        sta     z:SFX_buffer_position
        sta     f:GSU_FRAME_HALF
        lda     #%00011101
        sta     GSU_SCMR
        gsuOn
        endVBlank

drawScreen1:
        lda     z:SFX_buffer_position
        bne     @copyHalf1
        VRAM_memcpy VRAM_screen_1, screenbuffer, screenbuffer_len
        lda     #$01
        sta     z:SFX_buffer_position
        sta     f:GSU_FRAME_HALF
        lda     #%00011101
        sta     GSU_SCMR
        gsuOn
        endVBlank
@copyHalf1:
        VRAM_memcpy (VRAM_screen_1 + screenbuffer_len), screenbuffer, screenbuffer_len
        stz     z:SFX_buffer_position
        lda     #$00
        sta     f:GSU_FRAME_HALF
        lda     #$01
        sta     z:VRAM_screen_select
        lda     #bg12nba(VRAM_screen_1, 0)
        sta     BG12NBA
        lda     #%00011101
        sta     GSU_SCMR
        gsuOn
        endVBlank

; ==============================================================================
; Level Descriptor & BG1 Tilemap in RODATA ($80)
; ==============================================================================
.segment "RODATA"
.include "backgroundMap.s"

ProtagonistRoomDef:
        .word   $0000
        def_rom_asset RoomAtlasBin, (RoomAtlasBinEnd - RoomAtlasBin)
        def_rom_asset RoomAtlasTab, (RoomAtlasTabEnd - RoomAtlasTab)
        def_rom_asset RoomAtlasPal, 32
        def_rom_asset RoomMapBin,   (RoomMapBinEnd - RoomMapBin)

; ==============================================================================
; Bank $82: PROTAGONIST_ROOM_ATLAS (128x128) + protagonist_room (8x8)
; ==============================================================================
.segment "ROM2"
RoomAtlasBin:
        .incbin "Data/PROTAGONIST_ROOM_ATLAS.bin"
RoomAtlasBinEnd:

RoomAtlasTab:
        .incbin "Data/PROTAGONIST_ROOM_ATLAS.tab"
RoomAtlasTabEnd:

RoomAtlasPal:
        .incbin "Data/PROTAGONIST_ROOM_ATLAS.pal"

RoomMapBin:
        .incbin "Data/protagonist_room.map"
RoomMapBinEnd:
