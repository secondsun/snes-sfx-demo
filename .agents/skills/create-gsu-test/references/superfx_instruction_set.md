# SuperFX (GSU) Instruction Set & Architecture Manual

This document provides a reference manual for the SuperFX (GSU) processor architecture, internal registers, execution pipeline, and complete instruction set.

> [!NOTE]
> This project specifically targets the **SuperFX 3 (FX3)**. For FX3 architectural enhancements, simultaneous bus access, memory mapping differences, and the software replacement for the repurposed `MERGE` opcode, see [SuperFX 3 (FX3) Specifications](./fx3_specifications.md).

---

## 1. Architectural Overview

### 1.1 Key Features
- **16-Bit RISC-like Architecture**: Instructions are 1 byte wide when running from cache.
- **Clock Operation**: Standard GSU runs at 10.74 MHz (GSU-1) or 21.4 MHz (GSU-2). FX3 runs at 150 MHz on RP2350B (~4x standard GSU in MesenCE).
- **512-Byte Instruction Cache**: 32 blocks of 16 bytes each. Executing from cache permits simultaneous access to external ROM and RAM.
- **Dual Bus Architecture**: Independent ROM reading buffer and RAM writing buffer operate in parallel with instruction execution.
- **Pipelined Execution**: Pre-fetches the next instruction while executing the current one. Delay slots apply to branch and jump instructions.
- **Hardware Bitmap / Plot Emulation**: Converts bitmapped coordinates directly to SNES PPU character blocks (Mode 20 planar tiles or FX3 chunky frame buffer).

---

## 2. Register Summary

The GSU provides sixteen 16-bit general registers (`R0`–`R15`) and dedicated hardware control registers:

| Register | Name | Size | Function / Convention |
| :--- | :--- | :--- | :--- |
| **`R0`** | Accumulator / General | 16-bit | Default source (`Sreg`) and destination (`Dreg`) for operations. Primary function argument. |
| **`R1`** | Plot X / General | 16-bit | Pixel plot X coordinate; destination pointer for memory transfer macros. |
| **`R2`** | Plot Y / General | 16-bit | Pixel plot Y coordinate. |
| **`R3`** | General / Return Val | 16-bit | General purpose; convention return value for functions. |
| **`R4`** | Math Result Low | 16-bit | Holds lower 16 bits of 32-bit result for `LMULT`. |
| **`R5`** | General | 16-bit | General purpose. |
| **`R6`** | Multiplier | 16-bit | Multiplicand register for `FMULT` and `LMULT`. |
| **`R7`** | Merge Source 1 | 16-bit | Texel X source for legacy `MERGE`. |
| **`R8`** | Merge Source 2 | 16-bit | Texel Y source for legacy `MERGE`. |
| **`R9`** | General | 16-bit | General purpose. |
| **`R10`** | Stack Pointer | 16-bit | **Stack Pointer** (by project convention). Initialized via `init_stack`. |
| **`R11`** | Link Register | 16-bit | Subroutine return address target set by `LINK #n`. |
| **`R12`** | Loop Counter | 16-bit | Hardware counter decremented by `LOOP`. |
| **`R13`** | Loop Address | 16-bit | Hardware branch target address for `LOOP`. |
| **`R14`** | ROM Pointer | 16-bit | ROM data buffer address pointer. Loading or incrementing `R14` initiates prefetch. |
| **`R15`** | Program Counter (PC)| 16-bit | Writing `R15` branches execution. Cleared to `$0000` on `STOP` in FX3. |
| **`SFR`** | Status/Flag Register| 16-bit | Processor flags (`Z`, `CY`, `S`, `OV`, `G`, `R`, `ALT1`, `ALT2`, `IL`, `IH`, `B`, `IRQ`). |
| **`PBR`** | Program Bank Reg | 8-bit | Specifies 64KB bank where instructions are fetched. |
| **`ROMBR`**| ROM Bank Register | 8-bit | Specifies ROM bank accessed by `R14` buffer. Set with `ROMB`. |
| **`RAMBR`**| RAM Bank Register | 1/8-bit | Specifies RAM bank accessed by RAM loads/stores. Set with `RAMB`. |
| **`CBR`** | Cache Base Register | 16-bit | Specifies base address for 512-byte cache RAM. |
| **`SCBR`** | Screen Base Reg | 8-bit | Specifies base address for character data in RAM (`Start = $700000 + SCBR * $400`). |
| **`SCMR`** | Screen Mode Reg | 8-bit | Sets screen height (128, 160, 192, OBJ) and color mode (4, 16, 256 colors). |
| **`COLR`** | Color Register | 8-bit | Holds color value plotted by `PLOT`. Set with `COLOR` or `GETC`. |
| **`POR`**  | Plot Option Register| 5-bit | Plot mode options (transparency, dither, high nibble, OBJ mode). Set with `CMODE`. |
| **`CFGR`** | Config Register | 8-bit | Multiplier speed mode (`MS0`) and IRQ mask flag. |
| **`CLSR`** | Clock Select Reg | 1-bit | Clock frequency (0: 10.74 MHz, 1: 21.4 MHz / high-speed). |

---

## 3. Status/Flag Register (SFR) Bits

```
Bit:  15   14   13   12   11   10    9     8     7    6    5    4    3    2    1    0
Name: IRQ   -    -    B   IH   IL  ALT2  ALT1    -    R    G   OV    S   CY    Z    -
```

- **`Z` (Zero)**: Set if operation result equals zero.
- **`CY` (Carry)**: Set on unsigned carry or arithmetic borrow / shift output.
- **`S` (Sign)**: Set if bit 15 of result is 1 (negative).
- **`OV` (Overflow)**: Set on signed arithmetic overflow.
- **`G` (Go)**: Set to 1 while GSU is executing; cleared to 0 when GSU stops.
- **`R` (ROM Read)**: Set to 1 while `R14` ROM buffer prefetch is in progress.
- **`ALT1` / `ALT2`**: Mode prefixes set by `ALT1`, `ALT2`, or `ALT3` instructions.
- **`B`**: Prefix flag set by `WITH` instruction. Modifies subsequent `TO` into `MOVE` and `FROM` into `MOVES`.
- **`IRQ`**: Interrupt flag set when GSU completes execution via `STOP`.

---

## 4. Pipeline Execution & Delay Slots

### 4.1 Branch & Jump Delay Slots
When a branch (`BNE`, `BEQ`, `BRA`, etc.) or jump (`JMP`, `LJMP`) is taken, the instruction immediately following the branch in memory has already been fetched into the pipeline. **That single instruction is executed before branching to the target!**

```assembly
    BNE target
    INC r1        ; <-- THIS INSTRUCTION ALWAYS EXECUTES (delay slot)!
```
If you do not want an instruction executed in the delay slot, insert a `NOP`:
```assembly
    BNE target
    NOP           ; Harmless delay slot
```

### 4.2 Two-Byte Instructions in Delay Slots
Never place an instruction longer than 1 byte immediately after a branch without a `NOP`. A multi-byte instruction's immediate operand will be misinterpreted by the branch pipeline.

---

## 5. Register & Flag Prefix Architecture

The GSU achieves single-byte opcode density by using prefix instructions to configure operands:

### 5.1 Register Prefixes (`TO`, `FROM`, `WITH`)
- `FROM Rn`: Sets `Sreg` to `Rn`.
- `TO Rn`: Sets `Dreg` to `Rn`.
- `WITH Rn`: Sets both `Sreg` and `Dreg` to `Rn`, and sets the **`B` flag**.
- *Default*: If not specified, `Sreg` and `Dreg` default to `R0`. Any non-prefix instruction resets `Sreg` and `Dreg` to `R0`.

### 5.2 The `B` Flag and Moves
- `WITH R5` followed by `TO R4` executes as `MOVE R4, R5` (`R5 -> R4`).
- `WITH R5` followed by `FROM R4` executes as `MOVES R4, R5` (`R4 -> R5` with flags set).

### 5.3 Mode Prefixes (`ALT1`, `ALT2`, `ALT3`)
Modifies the meaning of the subsequent instruction:
- `ALT1` + `ADD Rn` = `ADC Rn` (Add with carry)
- `ALT2` + `ADD Rn` = `ADD #n` (Add immediate)
- `ALT3` + `ADD Rn` = `ADC #n` (Add immediate with carry)
- `ALT1` + `MULT Rn` = `UMULT Rn` (Unsigned multiply)
- `ALT1` + `SUB Rn` = `SBC Rn` (Subtract with carry)
- `ALT3` + `SUB Rn` = `CMP Rn` (Compare)
- `ALT1` + `LDW (Rn)` = `LDB (Rn)` (Load byte)
- `ALT1` + `STW (Rn)` = `STB (Rn)` (Store byte)

---

## 6. ROM and RAM Buffering Mechanics

### 6.1 ROM Read Buffer (`R14`)
Loading `R14` (`IWT R14, #addr` or `MOVE R14, Rn`) or executing `INC R14` triggers an automatic hardware read from ROM into the ROM buffer.
- `GETB`: Moves the buffered ROM byte into `Dreg` (zero-extended).
- `GETBH`: Moves buffered byte into high byte of `Dreg`, keeping low byte of `Sreg`.
- `GETBL`: Moves buffered byte into low byte of `Dreg`, keeping high byte of `Sreg`.
- `GETBS`: Moves buffered byte into low byte with sign extension into bits 8–15.

### 6.2 RAM Write Buffer & Settling Delay
Stores to RAM (`STB`, `STW`, `SM`, `SMS`, `SBK`) are buffered asynchronously in hardware.
- Writing to RAM does not stall execution immediately unless a second store is initiated before the first finishes (`RamDelay` cycles).
- **Unit Test Implication**: When writing results to `OUTPUT` in RAM before halting at `test_stop:`, you must insert **8 NOPs** to allow the write pipeline to settle before the Mesen Lua breakpoint checks RAM.

---

## 7. Complete Alphabetical Instruction Reference

### `ADC Rn` / `ADC #n`
- **Operation**: `Sreg + Rn + CY -> Dreg` (or `Sreg + #n + CY -> Dreg`)
- **Flags**: `OV`, `S`, `CY`, `Z` updated.

### `ADD Rn` / `ADD #n`
- **Operation**: `Sreg + Rn -> Dreg` (or `Sreg + #n -> Dreg`)
- **Flags**: `OV`, `S`, `CY`, `Z` updated.

### `ALT1` / `ALT2` / `ALT3`
- **Operation**: Sets mode flags `ALT1`, `ALT2`, or both for the following instruction.
- **Flags**: Affects `ALT1`, `ALT2` flags in SFR.

### `AND Rn` / `AND #n`
- **Operation**: `Sreg AND Rn -> Dreg` (or `Sreg AND #n -> Dreg`)
- **Flags**: `S`, `Z` updated.

### `ASR`
- **Operation**: Arithmetic shift right by 1. Bit 15 unchanged, Bit 0 -> `CY`.
- **Flags**: `S`, `CY`, `Z` updated.

### `BCC e` / `BCS e`
- **Operation**: Branch if carry clear (`CY=0`) / carry set (`CY=1`). Relative offset `-128` to `+127`.
- **Delay Slot**: Next instruction is executed before branch takes effect.

### `BEQ e` / `BNE e`
- **Operation**: Branch if zero (`Z=1`) / not zero (`Z=0`). Relative offset `-128` to `+127`.
- **Delay Slot**: Next instruction is executed before branch takes effect.

### `BGE e` / `BLT e`
- **Operation**: Branch if signed greater/equal (`S XOR OV = 0`) / less than (`S XOR OV = 1`).
- **Delay Slot**: Next instruction is executed before branch takes effect.

### `BIC Rn` / `BIC #n`
- **Operation**: Bit clear: `Sreg AND (NOT Rn) -> Dreg`.
- **Flags**: `S`, `Z` updated.

### `BMI e` / `BPL e`
- **Operation**: Branch if minus (`S=1`) / plus (`S=0`).
- **Delay Slot**: Next instruction is executed before branch takes effect.

### `BRA e`
- **Operation**: Unconditional branch. Relative offset `-128` to `+127`.
- **Delay Slot**: Next instruction is executed before branch takes effect.

### `BVC e` / `BVS e`
- **Operation**: Branch if overflow clear (`OV=0`) / overflow set (`OV=1`).
- **Delay Slot**: Next instruction is executed before branch takes effect.

### `CACHE`
- **Operation**: If `CBR != (R15 & $FFF0)`, sets `CBR = R15 & $FFF0` and clears all cache tags. Subsequent instructions are loaded into cache.

### `CMODE`
- **Operation**: `Sreg[4:0] -> POR` (Plot Option Register). Sets transparency, dither, high nibble, and OBJ bitmap modes.

### `CMP Rn`
- **Operation**: Subtracts `Rn` from `Sreg` to set flags without storing result.
- **Flags**: `OV`, `S`, `CY`, `Z` updated.

### `COLOR`
- **Operation**: `Sreg[7:0] -> COLR` (Color Register).

### `DEC Rn`
- **Operation**: `Rn - 1 -> Rn` (registers `R0`–`R14`).
- **Flags**: `S`, `Z` updated.

### `DIV2`
- **Operation**: Special divide by 2: If `Sreg == -1 ($FFFF)`, returns `0`; otherwise arithmetic shift right.
- **Flags**: `S`, `CY`, `Z` updated.

### `FMULT`
- **Operation**: Fractional signed multiply: `(Sreg * R6) >> 16 -> Dreg`.
- **Caution**: Do not use `R4` as destination register.

### `FROM Rn`
- **Operation**: If `B=0`, sets `Sreg = Rn`. If `B=1`, performs `MOVES Rn, Sreg`.

### `GETB` / `GETBH` / `GETBL` / `GETBS`
- **Operation**: Loads byte from ROM buffer (`R14` address) into `Dreg` (zero-extended, high byte, low byte, or sign-extended).

### `GETC`
- **Operation**: Loads byte from ROM buffer directly into `COLR`.

### `HIB`
- **Operation**: `(Sreg >> 8) -> Dreg` (upper byte moved to lower byte, upper byte zeroed).
- **Flags**: `S`, `Z` updated.

### `IBT Rn, #pp`
- **Operation**: Loads 8-bit signed immediate `#pp` into `Rn` with sign extension to 16 bits.

### `INC Rn`
- **Operation**: `Rn + 1 -> Rn` (registers `R0`–`R14`).
- **Flags**: `S`, `Z` updated.

### `IWT Rn, #xxxx`
- **Operation**: Loads 16-bit immediate word `#xxxx` into `Rn`.

### `JMP Rn`
- **Operation**: `Rn -> R15 (PC)` (registers `R8`–`R13`).
- **Delay Slot**: Next instruction executes before jump takes effect.

### `LDB (Rm)`
- **Operation**: Loads byte from RAM at `(Rm)` into low byte of `Dreg`, high byte zeroed (`Rm` = `R0`–`R11`).

### `LDW (Rm)`
- **Operation**: Loads 16-bit word from RAM at `(Rm)` into `Dreg` (`Rm` = `R0`–`R11`). Requires word alignment.

### `LEA Rn, xxxx`
- **Operation**: Loads 16-bit address/immediate into `Rn`.

### `LINK #n`
- **Operation**: `R15 + #n -> R11` (`#n` = 1..4). Used to save subroutine return address in `R11`.

### `LJMP Rn`
- **Operation**: Long jump: `Rn -> R15 (PC)`, `Sreg[7:0] -> PBR`. Jumps across banks (`Rn` = `R8`–`R13`).
- **Delay Slot**: Next instruction executes before jump takes effect.

### `LM Rn, (xx)` / `LMS Rn, (yy)`
- **Operation**: Load memory word from 16-bit address `(xx)` or short address `(yy)` into `Rn`.

### `LMULT`
- **Operation**: 16x16 signed multiply: `Sreg * R6 -> (Dreg:R4)` (upper 16 bits in `Dreg`, lower 16 bits in `R4`).

### `LOB`
- **Operation**: Clears upper byte of `Sreg` to `00H`, stores lower byte into `Dreg`.
- **Flags**: `S`, `Z` updated.

### `LOOP`
- **Operation**: `R12 = R12 - 1`. If `R12 != 0`, branches to `R13`.
- **Delay Slot**: Next instruction executes before loop branch takes effect.

### `LSR`
- **Operation**: Logical shift right by 1: Bit 0 -> `CY`, Bit 15 = 0.
- **Flags**: `S=0`, `CY`, `Z` updated.

### `MERGE` (`$70`)
- **Standard SuperFX**: Merges `R7` (high byte) and `R8` (low byte) into `Dreg`.
- **SuperFX 3 (FX3)**: **Repurposed for firmware C2P/Clear functions!** Use the [FX3 Software Merge Macro](./fx3_specifications.md#software-replacement-macro-for-merge) instead.

### `MULT Rn` / `MULT #n`
- **Operation**: Signed 8x8 multiply: `Sreg[7:0] * Rn[7:0] -> Dreg` (16-bit signed result).
- **Flags**: `S`, `Z` updated.

### `NOP`
- **Operation**: No operation. Clears `ALT1`, `ALT2`, and `B` flags.

### `NOT`
- **Operation**: One's complement bitwise inversion: `~Sreg -> Dreg`.
- **Flags**: `S`, `Z` updated.

### `OR Rn` / `OR #n`
- **Operation**: Bitwise logical OR: `Sreg OR Rn -> Dreg`.
- **Flags**: `S`, `Z` updated.

### `PLOT`
- **Operation**: Plots pixel of color in `COLR` to coordinates `(R1, R2)`. Increments `R1`.

### `RAMB`
- **Operation**: `Sreg[7:0] -> RAMBR` (sets RAM bank for memory operations).

### `ROL` / `ROR`
- **Operation**: Rotate left / rotate right through carry flag.
- **Flags**: `S`, `CY`, `Z` updated.

### `ROMB`
- **Operation**: `Sreg[7:0] -> ROMBR` (sets ROM bank for `R14` buffering).

### `RPIX`
- **Operation**: Flushes pixel cache to RAM and reads pixel color at `(R1, R2)` into `Dreg`.

### `SBC Rn`
- **Operation**: Subtract with borrow: `Sreg - Rn - CY -> Dreg`.
- **Flags**: `OV`, `S`, `CY`, `Z` updated.

### `SBK`
- **Operation**: Stores `Sreg` into the last accessed RAM address (bulk processing).

### `SEX`
- **Operation**: Sign extends low byte of `Sreg` (bit 7 copied to bits 8–15) into `Dreg`.
- **Flags**: `S`, `Z` updated.

### `SM (xx), Rn` / `SMS (yy), Rn`
- **Operation**: Store 16-bit word from `Rn` into RAM address `(xx)` or short address `(yy)`.

### `STB (Rm)`
- **Operation**: Stores low byte of `Sreg` into RAM at `(Rm)` (`Rm` = `R0`–`R11`).

### `STOP`
- **Operation**: Clears `GO` flag in SFR, signals IRQ to SNES CPU, and halts GSU. On FX3, clears `R15` to `0`.

### `STW (Rm)`
- **Operation**: Stores 16-bit word from `Sreg` into RAM at `(Rm)` (`Rm` = `R0`–`R11`). Requires word alignment.

### `SUB Rn` / `SUB #n`
- **Operation**: `Sreg - Rn -> Dreg` (or `Sreg - #n -> Dreg`).
- **Flags**: `OV`, `S`, `CY`, `Z` updated.

### `SWAP`
- **Operation**: Swaps high and low bytes of `Sreg` into `Dreg`.
- **Flags**: `S`, `Z` updated.

### `TO Rn`
- **Operation**: If `B=0`, sets `Dreg = Rn`. If `B=1`, performs `MOVE Rn, Sreg`.

### `UMULT Rn` / `UMULT #n`
- **Operation**: Unsigned 8x8 multiply: `Sreg[7:0] * Rn[7:0] -> Dreg` (16-bit unsigned result).
- **Flags**: `S`, `Z` updated.
