# 16-bit Accumulator CPU

## How it works

This is a small custom 16-bit accumulator-based CPU: program counter, program ROM,
instruction register/decoder, ALU, accumulator, an 8-word RAM, and a control unit
that decodes a 4-bit opcode into control signals each cycle (see `cpu.v` for the
full core and `docs/isa.md`-style comments inline for the opcode table). The demo
program baked into the ROM exercises most of the instruction set: load immediate,
add, store/load RAM, subtract-and-branch-on-zero, load-upper-byte, read the input
port, and write the output port, before halting.

Tiny Tapeout only exposes 8 dedicated inputs, 8 dedicated outputs, and 8
bidirectional pins per tile, but this CPU has a 16-bit input, a 16-bit output, and
a 6-bit debug (program counter) output. `project.v` is a thin wrapper that
multiplexes those wide ports onto the 8-bit pins TT provides:

- `ui_in[7:0]` carries one byte at a time.
- `uio_in[3]` (`load_strobe`) and `uio_in[2]` (`load_half`) control loading that
  byte into the low or high half of a 16-bit input register, which feeds the CPU's
  `main_input`.
- `uio_in[1:0]` (`out_sel`) picks which byte appears on `uo_out`: the low or high
  byte of the CPU's `main_output`, or the program counter (for debugging).

## How to test

1. Hold reset (`rst_n` low) for a couple of clock cycles, then release it.
2. To load a 16-bit input value: put the low byte on `ui_in`, set `uio_in[2]=0`,
   pulse `uio_in[3]` high for one clock, then repeat with the high byte and
   `uio_in[2]=1`.
3. Set `uio_in[1:0] = 2'b10` to watch the program counter on `uo_out` as the CPU
   runs; it should count up and jump partway through the demo program.
4. Once the CPU reaches its `OUT` instruction, set `uio_in[1:0] = 2'b00` /
   `2'b01` to read the low/high byte of `main_output` off `uo_out`.

`test/test.py` is a cocotb test that walks through exactly this sequence
(loading 0xBEEF, watching the PC jump, checking both output bytes) and is
what the GitHub Actions CI runs. From the `test/` directory: `make -B`.
See `test/README.md` for details, including an optional plain-Verilog
testbench for quick iteration without cocotb.

To load your own program instead of the demo one, edit the `case` statement in
the `program_rom` module in `cpu.v` — each entry is `address: instruction`.

## External hardware

None. This design only uses the standard Tiny Tapeout demo board pins.
