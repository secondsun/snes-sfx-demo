; Shared memory addresses between SuperFX (GSU) and 65816 S-CPU
; Bank $70:0000..$70:7FFF holds GSURAM working buffers & stack;
; Bank $70:8000..$70:A7FF holds the 10 KB 128x160 4bpp half-screen buffer;
; Bank $71:0000..$71:902F holds dynamically staged .bin, .tab, .map, and .pal.

.include "libSFX.i"

screenbuffer          = $708000 ; 10 KB half-screen buffer in Bank $70 (GSU_SCBR = $20)
screenbuffer_len      = $2800   ; 128 dots * 160 lines * 4bpp = 10,240 bytes

; VRAM Layout
VRAM_tilemap          = $E800   ; 32x32 BG1 tilemap
VRAM_screen_1         = $0000   ; Double-buffer 1 ($0000..$4FFF)
VRAM_screen_2         = $6000   ; Double-buffer 2 ($6000..$AFFF)
