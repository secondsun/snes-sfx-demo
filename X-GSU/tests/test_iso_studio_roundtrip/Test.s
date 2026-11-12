; ==============================================================================
; TEST_ISO_STUDIO_ROUNDTRIP - SNES 65816 Host Harness
; Stages real `sfx-studio` CLI-packed `.bin`, `.tab`, `.pal`, and `.map` assets
; from LoROM Bank `$85` (`ROM5`) into Game Pak RAM Bank `$71` + PPU CGRAM via
; `cpu_asset_loader.i` + `asset_source_rom.i`, then launches GSU verification.
; ==============================================================================
.include "libSFX.i"
.include "../../gsu_iso/cpu_asset_loader.i"
.include "../../gsu_iso/asset_source_rom.i"
.include "Data/roundtrip_map.i"

.import GSU_Code
.import CPU_STAGE_SNAP

Main:
        memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
        memcpy __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__

        ; Initialize Bank-$71 loader with 4bpp 160-line GSU_SCMR = %00011101
        SFX_LOADER_INIT %00011101

        ; Stage Studio-packed RoundtripLevelDef from ROM5 ($85) -> Bank $71 + CGRAM
        SFX_LOAD_LEVEL RoundtripLevelDef

        ; Temporarily release GSU bus to snapshot 65816 + PPU CGRAM state into GSURAM
        RW a8i16
        stz     GSU_SCMR

        ; Read back PPU CGRAM color 2 (grass dark green = $2247) via CGDATAREAD ($213B)
        lda     #$02
        sta     CGADD
        lda     CGDATAREAD
        xba
        lda     CGDATAREAD
        and     #$7F
        xba                     ; 16-bit C = BGR555 word at CGRAM[2]
        RW a16
        sta     f:CPU_STAGE_SNAP + 0

        lda     a:sfx_atlas_load_count
        sta     f:CPU_STAGE_SNAP + 2
        lda     a:sfx_resident_atlas_id
        sta     f:CPU_STAGE_SNAP + 4

        RW a8
        lda     a:sfx_gsu_load_lock
        sta     f:CPU_STAGE_SNAP + 6
        lda     #$00
        sta     f:CPU_STAGE_SNAP + 7

        jml     __MAIN_LOOP_RUN__

.segment "RODATA"
RoundtripLevelDef:
        .word   $0000                                                   ; atlas_id = 0
        def_rom_asset RoundtripAtlasBin, (RoundtripAtlasBinEnd - RoundtripAtlasBin)
        def_rom_asset RoundtripAtlasTab, (RoundtripAtlasTabEnd - RoundtripAtlasTab)
        def_rom_asset RoundtripAtlasPal, (RoundtripAtlasPalEnd - RoundtripAtlasPal)
        def_rom_asset RoundtripMapBin,   ROUNDTRIP_MAP_MAP_BYTE_SIZE

.segment "ROM5"
RoundtripAtlasBin:
        .incbin "Data/ROUNDTRIP_ATLAS.bin"
RoundtripAtlasBinEnd:
RoundtripAtlasTab:
        .incbin "Data/ROUNDTRIP_ATLAS.tab"
RoundtripAtlasTabEnd:
RoundtripAtlasPal:
        .incbin "Data/ROUNDTRIP_ATLAS.pal"
RoundtripAtlasPalEnd:
RoundtripMapBin:
        .incbin "Data/roundtrip_map.map"

.segment "MAIN_LOOP"
        RW a8i16
        ldx     #$A000
        lda     #$00
:       sta     $700000, x
        inx
        cpx     #$C800
        bne     :-

        lda     #$70
        sta     GSU_PBR
        lda     #$28
        sta     GSU_SCBR        ; $70:A000 framebuffer
        lda     #%00011101
        sta     GSU_SCMR
        lda     #%10000000
        sta     GSU_CFGR
        lda     #$01
        sta     GSU_CLSR
        lda     #$04
        sta     GSU_ROMBR

        ldx     #.loword(GSU_Code)
        stx     GSU_R15

        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp
        VBL_on

:       wai
        bra     :-
