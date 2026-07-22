; libSFX S-CPU to GSU Register Definitions
; David Lindecrantz <optiroc@gmail.com>

.ifndef ::__MBSFX_CPU_GSU__
::__MBSFX_CPU_GSU__ = 1

GSU_SRAM        = $700000

;-------------------------------------------------------------------------------
;GSU MMIO Registers (mirrored in banks 00h-3Fh and 80h-BFh)
;During GSU operation, only SFR, SCMR, and VCR may be accessed

GSU_R0          = $7000 ;Default source/destination
GSU_R1          = $7002 ;PLOT instruction X coordinate
GSU_R2          = $7004 ;PLOT instruction Y coordinate
GSU_R3          = $7006 ;General purpose
GSU_R4          = $7008 ;LMULT instruction, lower 16 bits of result
GSU_R5          = $700a ;General purpose
GSU_R6          = $700c ;FMULT and LMULT instructions, multiplication
GSU_R7          = $700e ;MERGE instruction, source 1
GSU_R8          = $7010 ;MERGE instruction, source 2
GSU_R9          = $7012 ;General purpose
GSU_R10         = $7014 ;General purpose (stack pointer by convention)
GSU_R11         = $7016 ;LINK instruction destination
GSU_R12         = $7018 ;LOOP instruction counter
GSU_R13         = $701a ;LOOP instruction branch address
GSU_R14         = $701c ;Game Pak ROM address pointer (for GETxx instructions)
GSU_R15         = $701e ;Program counter, write MSB to start operation

GSU_SFR         = $7030 ;Status/Flag Register
GSU_PBR         = $7034 ;Program Bank Register
GSU_ROMBR       = $7036 ;Game Pak ROM Bank Register
GSU_RAMBR       = $703c ;Game Pak RAM Bank Register
GSU_CBR         = $703e ;Cache Base Register
GSU_SCBR        = $7038 ;Screen Base Register
GSU_SCMR        = $703a ;Screen Mode Register

GSU_BRAMR       = $7033 ;Back-up RAM Register
GSU_VCR         = $703b ;Version Code Register
GSU_CFGR        = $7037 ;Config Register
GSU_CLSR        = $7039 ;Clock Select Register

GSU_CACHE       = $7100 ;GSU Cache RAM

.endif;__MBSFX_CPU_GSU__
