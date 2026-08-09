# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

# uio_in bit assignments (see docs/info.md):
#   uio_in[1:0] = out_sel   (00: main_output low byte, 01: high byte, 10: pc)
#   uio_in[2]   = load_half (0: low byte of input reg, 1: high byte)
#   uio_in[3]   = load_strobe


async def load_byte(dut, high_half: bool, data: int):
    """Latch one byte into the CPU's 16-bit input register."""
    await RisingEdge(dut.clk)
    dut.ui_in.value = data
    load_half_bit = 1 << 2 if high_half else 0
    dut.uio_in.value = (int(dut.uio_in.value) & 0b1110_0011) | (1 << 3) | load_half_bit
    await RisingEdge(dut.clk)
    # drop the strobe again
    dut.uio_in.value = int(dut.uio_in.value) & 0b1111_0111


def set_out_sel(dut, sel: int):
    dut.uio_in.value = (int(dut.uio_in.value) & 0b1111_1100) | (sel & 0b11)


@cocotb.test()
async def test_cpu(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    # Load main_input = 0xBEEF via the byte interface (low byte, then high byte)
    dut._log.info("Loading main_input = 0xBEEF")
    await load_byte(dut, False, 0xEF)
    await load_byte(dut, True, 0xBE)

    # Watch the program counter (out_sel = 2'b10) advance and jump as the
    # built-in demo program runs (it includes a taken JZ, so pc should skip
    # ahead partway through).
    set_out_sel(dut, 0b10)
    seen_pc = []
    for _ in range(11):
        await RisingEdge(dut.clk)
        seen_pc.append(int(dut.uo_out.value))
    dut._log.info(f"pc trace: {seen_pc}")
    assert 9 in seen_pc, "expected the JZ branch to land on address 9"
    assert seen_pc == sorted(seen_pc), "pc should only ever move forward/jump, never backward"

    # By now the demo program has executed its OUT instruction, writing
    # main_input back out to main_output. Check both bytes read back
    # correctly through the output mux.
    set_out_sel(dut, 0b00)  # main_output low byte
    await ClockCycles(dut.clk, 1)
    assert int(dut.uo_out.value) == 0xEF, f"expected low byte 0xEF, got {int(dut.uo_out.value):#04x}"

    set_out_sel(dut, 0b01)  # main_output high byte
    await ClockCycles(dut.clk, 1)
    assert int(dut.uo_out.value) == 0xBE, f"expected high byte 0xBE, got {int(dut.uo_out.value):#04x}"

    dut._log.info("CPU test passed")
