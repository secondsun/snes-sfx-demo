; ==============================================================================
; pointers.s - Shared Memory & VRAM Layout Contract for IsoRPGDemo
;
; Matches `snes_ui/README.md` VRAM Allocation Contract:
;   $0000..$3BFF : BG1 Double-Buffer 0 (192x160 4bpp = 480 tiles; blank $3C00)
;   $4000..$7BFF : BG1 Double-Buffer 1 (192x160 4bpp = 480 tiles; blank $7C00)
;   $C000..$DFFF : OBJ Name Table 0 (VRAM_UI_OBJ_TILES, 256 4bpp 8x8 tiles)
;   $E000..$E7FF : BG3 Font & 9-Slice Window Tiles (VRAM_BG3_TILES)
;   $E800..$EFFF : BG1 32x32 Tilemap (VRAM_tilemap)
;   $F000..$F7FF : BG3 32x32 Shadow-Flushed Tilemap (VRAM_BG3_MAP)
;
; Bank $70/$71 Game Pak RAM:
;   $70:0000..$70:7FFF : GSURAM working buffers, stack & GSU_SCENE_DESC
;   $70:8000..$70:A7FF : 10 KB half-screen buffer (GSU_SCBR = $20)
;   $71:0000..$71:902F : Dynamically staged .bin, .tab, .map, and .pal
; ==============================================================================

.include "libSFX.i"

screenbuffer          = $708000 ; 10 KB half-screen buffer in Bank $70 (GSU_SCBR = $20)
screenbuffer_pass0    = $2800   ; Pass 0: 16 tile cols * 20 rows * 32B = 10,240 bytes (X = 0..127)
screenbuffer_pass1    = $1400   ; Pass 1:  8 tile cols * 20 rows * 32B =  5,120 bytes (X = 128..191)

; VRAM Layout (byte addresses)
VRAM_screen_1         = $0000   ; BG1 Double-Buffer 0 ($0000..$3BFF, blank tile $01E0 at $3C00)
VRAM_screen_2         = $4000   ; BG1 Double-Buffer 1 ($4000..$7BFF, blank tile $01E0 at $7C00)
VRAM_tilemap          = $E800   ; 32x32 BG1 tilemap ($E800..$EFFF)
