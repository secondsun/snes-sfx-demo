# SuperFX 3 (FX3) Architecture & Specification Guide

This guide details the technical specifications, architectural improvements, and behavioral differences of the **SuperFX 3 (FX3)** processor (documented by Randy Linden, Limited Run Games: [snes-fx3](https://github.com/LimitedRunGames-Tech/snes-fx3)).

---

## 1. Overview & Comparison with SuperFX 1/2

The FX3 is an enhanced version of the SuperFX (GSU) chip implemented on modern FPGA/microcontroller hardware (Raspberry Pi RP2350B running at 150 MHz). While mostly backward-compatible with GSU instruction execution, several key hardware improvements and differences must be accounted for:

| Feature | Standard SuperFX (GSU 1 / 2) | SuperFX 3 (FX3) |
| :--- | :--- | :--- |
| **Bus Contention** | SNES CPU and GSU cannot access ROM/RAM concurrently (requires bus arbitration / WAIT states) | **Simultaneous Access**: 65816 and FX can access ROM and FX SRAM simultaneously without lockout |
| **Clock Speed** | 10.74 MHz (GSU-1) or 21.4 MHz (GSU-2) | **150 MHz RP2350B** (~4x original GSU throughput in MesenCE) |
| **FastROM** | Slow (200ns) or Fast (120ns) LoROM | Supported as **Mode $30** (Banks `$80-$FF`) |
| **FX Memory Capacity** | Up to 2 MB ROM | **3 MB** (Banks `$40-$6F` are 64KB banks) |
| **65816 Memory Capacity** | Standard LoROM mapping | **4 MB** (Banks `$C0-$FF` are 64KB banks) |
| **Hardware Registers** | Mirrored in `$00-$3F:3000-32FF` | Located at **`$00:7000`** |
| **`MERGE` Opcode (`$70`)** | Merges R7 (texel X) and R8 (texel Y) into high/low bytes | **Repurposed for Firmware Functions** (Chunky-to-Planar and Clear) |
| **Frame Buffer** | Planar tiles in SRAM via pixel cache / character blocks | Internal **Chunky Frame Buffer** (1 byte/pixel); `PLOT` writes directly at high speed |
| **Completion Notification** | Hardware IRQ to SNES CPU on `STOP` | **Hardware**: No FX IRQs; software polls `R15` (cleared to 0 on `STOP`).<br>**MesenCE**: IRQ supported on `STOP`. |
| **Version Code (VCR)** | Returns GSU version (e.g. `$01` or `$02`) | Returns **`$52`** |
| **Cartridge Header Type** | `$13` (ROM+GSU), `$14` (RAM), `$15` (SRAM) | **`$17`** (ROM+FX3+RAM), **`$18`** (ROM+FX3+SRAM) |

---

## 2. Memory Maps

### 2.1 SNES 65816 CPU Memory Map (Mode $30)
- **Banks `$00-$3F`**: Upper 32KB banks (`$8000-$FFFF`)
- **Banks `$40-$6F`**: 64KB banks (3 MB total FX data / ROM)
- **Banks `$70-$71`**: FX SRAM (`$0000-$FFFF` each bank = 128 KB total)
- **Banks `$80-$BF`**: Upper 32KB banks (FastROM mirror of `$00-$3F`)
- **Banks `$C0-$FF`**: 64KB banks (4 MB total, mirror of `$40-$6F`)

### 2.2 FX3 Coprocessor Memory Map
- **Banks `$00-$3F`**: Upper 32KB banks (mirrored to lower 32KB banks `$0000-$7FFF`)
- **Banks `$40-$6F`**: 64KB banks (3 MB total ROM)
- **Banks `$70-$71`**: FX SRAM (128 KB Work RAM)

---

## 3. Repurposing of Opcode `$70` (`MERGE`)

In the FX3 specification, opcode `$70` is repurposed for firmware-assisted operations when running on hardware.

### Firmware Functions
To invoke a firmware function, set `R0` to the function number and execute `$70`:
- `#0`: Chunky-To-Planar Third A
- `#1`: Chunky-To-Planar Third B
- `#2`: Chunky-To-Planar Third C
- `#3`: Clear Third A
- `#4`: Clear Third B
- `#5`: Clear Third C

*(Note: Under MesenCE emulation, Chunky-To-Planar execution is treated as a NOP.)*

### Software Replacement Macro for `MERGE`
Because opcode `$70` is repurposed, if the original `MERGE` functionality (combining R7 texel X and R8 texel Y) is needed, use the following replacement sequence:

```assembly
; SuperFX 3 Software MERGE replacement
; In:       r7 = high byte source 1, r8 = high byte source 2
; Out:      rDest = merged word (r7 high byte in high byte, r8 high byte in low byte)
; Clobbers: rTemp, flags
.macro fx3_merge rDest, rTemp
    move  rTemp, r7      ; Preserve r7
    from  r8
    to    rDest
    hib                  ; r8 high byte -> rDest low byte (upper byte zeroed)
    with  r7
    hib                  ; r7 high byte -> r7 low byte (upper byte zeroed)
    with  r7
    swap                 ; r7 low byte -> r7 high byte
    with  rDest
    or    r7             ; Combine both bytes into rDest
    move  r7, rTemp      ; Restore r7
.endmacro
```

---

## 4. Register Access & Program Execution

### Hardware Registers at `$00:7000`
- `GSU_R0`  to `GSU_R15`: `$7000` to `$701E`
- `GSU_SFR`:  `$7030`
- `GSU_PBR`:  `$7034`
- `GSU_ROMBR`: `$7036`
- `GSU_RAMBR`: `$703C`
- `GSU_CBR`:  `$703E`
- `GSU_SCBR`: `$7038`
- `GSU_SCMR`: `$703A`
- `GSU_VCR`:  `$703B` (returns `$52`)
- `GSU_CFGR`: `$7037`
- `GSU_CLSR`: `$7039`

### Reading R15 While Running
On the FX3, reading `R15` from the 65816 CPU while the GSU is executing is explicitly permitted.
- The `STOP` opcode (`$00`) clears `R15` to `0000H`.
- Software can determine when the FX has finished by polling `R15` until it reads `0`.
- In MesenCE emulation, `STOP` still raises the SNES IRQ signal if configured in `CFGR`.

### Simultaneous Bus Access
Unlike the original SuperFX chip, the SNES 65816 CPU does not need to disable ROM/RAM access (`RON`/`RAN` bits in `SCMR`) to prevent bus collision. Both processors have uninterrupted access to ROM and FX SRAM.
