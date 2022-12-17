;Shared memory addresses
;Between SFX and S-CPU

.include "libSFX.i"

;SFX Constants
sfx_code_start = $700000 ;address of the first sfx instruction
sfx_code_size  = $200 ;space allocated to the sfx code; we've default to 512 bytes
                        ;because it is the cache size of the sfxcpu 

screenbuffer = $704000 ; start of the SFX screen buffer 
                       ; This memory will be DMA'd into VRAM during V-Blank

screenbuffer_len = $1400 ; Size of the SB. We're using a 160 line 4 bpp screen mode
                          ; So 160 (lines) * 256 (dots / line) * 4 (bpp)                       
                          ; = 0x5000 bytes (20480 ) in decimal. 
screenbuffer_copy_len = $1400 ; How much to copy per vblank

;VRAM Constants
VRAM_tilemap = $E800; start of tileMap
VRAM_road_tilemap = $F000 ; start of road tile Data

VRAM_screen_1 = $0 ; Start of first frame of background
VRAM_screen_2 = $6000 ; start of second frame of background
VRAM_road_tiles = $C000 ; start of road tile map Data


