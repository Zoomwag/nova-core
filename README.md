# Nova Core

**Nova Core** is a custom 16-bit CPU designed and built from scratch in Verilog.

**Demo** https://zoomwag.github.io/nova-core/

The project is focused on learning how processors work by designing each major component individually and combining them into a complete CPU.
<img width="1609" height="1116" alt="image" src="https://github.com/user-attachments/assets/029c984d-e0ca-4d1a-8968-419b53add106" />

<img width="2443" height="1684" alt="image" src="https://github.com/user-attachments/assets/7bdb6bb1-2278-4eaf-ac99-e2bd8571ba45" />

Here are some images of the cpu


## Features

- 16-bit CPU architecture
- Custom instruction set
- Custom ALU
- Accumulator-based design
- Program counter
- Instruction register and decoder
- Control unit
- ROM and RAM
- Status flags
- Written entirely in Verilog

# NovaCore CPU Instruction Set

## Instruction format

Every NovaCore instruction is 16 bits wide:

```text
Bit:  15              12 11                              0
      ┌─────────────────┬─────────────────────────────────┐
      │  4-bit opcode   │         12-bit operand          │
      └─────────────────┴─────────────────────────────────┘
```

- The **opcode** tells the CPU what operation to perform.
- The **operand** can contain a constant, RAM address, or program address.
- Some instructions do not use the operand.

## Opcode table

| Hex opcode | Binary opcode | Instruction | Operand use | Operation | Flags updated |
|:---:|:---:|---|---|---|:---:|
| `0` | `0000` | `NOP` | Ignored | Do nothing and continue to the next instruction | None |
| `1` | `0001` | `LDI` | `operand[7:0]` contains an 8-bit constant | Load the constant into the accumulator: `ACC = {8'h00, operand[7:0]}` | `Z`, `N` |
| `2` | `0010` | `LUI` | `operand[7:0]` contains an 8-bit constant | Load the constant into the upper half of the accumulator while keeping the lower half | `Z`, `N` |
| `3` | `0011` | `ADDI` | `operand[7:0]` contains an 8-bit constant | Add the constant to the accumulator | `Z`, `C`, `N` |
| `4` | `0100` | `SUBI` | `operand[7:0]` contains an 8-bit constant | Subtract the constant from the accumulator | `Z`, `C`, `N` |
| `5` | `0101` | `ANDI` | `operand[7:0]` contains an 8-bit constant | Perform bitwise AND between the accumulator and the constant | `Z`, `N` |
| `6` | `0110` | `ORI` | `operand[7:0]` contains an 8-bit constant | Perform bitwise OR between the accumulator and the constant | `Z`, `N` |
| `7` | `0111` | `XORI` | `operand[7:0]` contains an 8-bit constant | Perform bitwise XOR between the accumulator and the constant | `Z`, `N` |
| `8` | `1000` | `LOAD` | `operand[2:0]` selects RAM address `0–7` | Load a 16-bit value from RAM into the accumulator | `Z`, `N` |
| `9` | `1001` | `STORE` | `operand[2:0]` selects RAM address `0–7` | Store the accumulator in RAM | None |
| `A` | `1010` | `JMP` | `operand[5:0]` contains a program address | Jump unconditionally to the selected instruction address | None |
| `B` | `1011` | `JZ` | `operand[5:0]` contains a program address | Jump when the zero flag is `1` | None |
| `C` | `1100` | `JNZ` | `operand[5:0]` contains a program address | Jump when the zero flag is `0` | None |
| `D` | `1101` | `IN` | Ignored | Read the 8-bit input port into the lower half of the accumulator | `Z`, `N` |
| `E` | `1110` | `OUT` | Ignored | Copy the accumulator into the 16-bit output register | None |
| `F` | `1111` | `HALT` | Ignored | Stop instruction execution until the CPU is reset | None |

## Detailed instruction behaviour

| Instruction | Behaviour |
|---|---|
| `NOP` | `PC = PC + 1` |
| `LDI` | `ACC = {8'h00, operand[7:0]}` |
| `LUI` | `ACC = {operand[7:0], ACC[7:0]}` |
| `ADDI` | `ACC = ACC + {8'h00, operand[7:0]}` |
| `SUBI` | `ACC = ACC - {8'h00, operand[7:0]}` |
| `ANDI` | `ACC = ACC AND {8'h00, operand[7:0]}` |
| `ORI` | `ACC = ACC OR {8'h00, operand[7:0]}` |
| `XORI` | `ACC = ACC XOR {8'h00, operand[7:0]}` |
| `LOAD` | `ACC = RAM[operand[2:0]]` |
| `STORE` | `RAM[operand[2:0]] = ACC` |
| `JMP` | `PC = operand[5:0]` |
| `JZ` | If `Z = 1`, set `PC = operand[5:0]`; otherwise increment `PC` |
| `JNZ` | If `Z = 0`, set `PC = operand[5:0]`; otherwise increment `PC` |
| `IN` | `ACC = {8'h00, input_pins}` |
| `OUT` | `output_register = ACC` |
| `HALT` | `halted = 1` |

## CPU flags

| Flag | Full name | Meaning |
|:---:|---|---|
| `Z` | Zero flag | Set to `1` when the new accumulator value is `16'h0000` |
| `C` | Carry flag | Stores the carry-out from arithmetic operations |
| `N` | Negative flag | Copies bit `15` of the new accumulator value |

## Machine-code examples

| Assembly instruction | Machine code | Explanation |
|---|:---:|---|
| `NOP` | `16'h0000` | Do nothing |
| `LDI 5` | `16'h1005` | Load decimal `5` into the accumulator |
| `LDI FF` | `16'h10FF` | Load hexadecimal `FF` into the accumulator |
| `LUI AB` | `16'h20AB` | Load hexadecimal `AB` into the upper byte |
| `ADDI 3` | `16'h3003` | Add decimal `3` to the accumulator |
| `SUBI 1` | `16'h4001` | Subtract decimal `1` from the accumulator |
| `ANDI 0F` | `16'h500F` | Keep only the lowest four bits |
| `ORI 80` | `16'h6080` | Set bit `7` |
| `XORI FF` | `16'h70FF` | Toggle the lowest eight bits |
| `LOAD 2` | `16'h8002` | Load RAM location `2` |
| `STORE 2` | `16'h9002` | Store the accumulator in RAM location `2` |
| `JMP 10` | `16'hA00A` | Jump to program address decimal `10` |
| `JZ 4` | `16'hB004` | Jump to address `4` when the zero flag is set |
| `JNZ 1` | `16'hC001` | Jump to address `1` when the zero flag is clear |
| `IN` | `16'hD000` | Read the external input pins |
| `OUT` | `16'hE000` | Copy the accumulator to the output register |
| `HALT` | `16'hF000` | Stop the CPU |

## Example program

This program counts down from `5` to `0`:

| Address | Assembly | Machine code | Purpose |
|:---:|---|:---:|---|
| `0` | `LDI 5` | `16'h1005` | Start the accumulator at `5` |
| `1` | `OUT` | `16'hE000` | Display the current value |
| `2` | `SUBI 1` | `16'h4001` | Subtract `1` |
| `3` | `JNZ 1` | `16'hC001` | Repeat while the result is not zero |
| `4` | `OUT` | `16'hE000` | Display the final zero |
| `5` | `HALT` | `16'hF000` | Stop the CPU |

## CPU specification summary

| Feature | Specification |
|---|---|
| CPU name | `Nova Core` |
| Architecture | 16-bit accumulator CPU |
| Data width | 16 bits |
| Instruction width | 16 bits |
| Opcode width | 4 bits |
| Operand width | 12 bits |
| Program counter width | 6 bits |
| Program capacity | 64 instructions |
| Data RAM | 8 words of 16 bits |
| External input | 8 bits |
| External output | 16 bits |
| Flags | Zero, carry, negative |
| Number of opcodes | 16 |
| Execution style | One instruction per clock cycle |
| Target platform | Tiny Tapeout |
