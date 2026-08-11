"""
Cocotb testbench for the 2x2 systolic MAC array.

Two cases are checked, both chosen so they can be verified by hand
without tracing the full systolic timing skew:

1. Both activation rows held at 0: every PE zero-skips, so every column
   output must be 0 regardless of what weights are loaded.

2. Row 1 held at 0 (so PE(1,0)/PE(1,1) always pass their column's psum
   through unchanged) while row 0 carries a constant value. This turns
   the array into two independent 1-deep MACs: column 0 must settle to
   act_row0 * w00, column 1 to act_row0 * w01, each two clock cycles
   after act_row0 is applied (one register stage in the top PE, one more
   in the bottom PE that forwards it).
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


async def reset(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


async def load_weight(dut, weight):
    """Pulse weight_load (uio_in[4]) for exactly one cycle with weight_in
    (uio_in[3:0]) set, loading the next PE in the fixed load order."""
    precision_sel = 0
    dut.uio_in.value = (precision_sel << 5) | (1 << 4) | (weight & 0xF)
    await RisingEdge(dut.clk)
    dut.uio_in.value = (precision_sel << 5) | (0 << 4) | (weight & 0xF)
    await RisingEdge(dut.clk)


def set_activations(dut, act_row0, act_row1):
    dut.ui_in.value = ((act_row1 & 0xF) << 4) | (act_row0 & 0xF)


@cocotb.test()
async def test_zero_activation_skips(dut):
    """Both rows held at 0 -> every column output must stay 0."""
    dut._log.info("start clock")
    cocotb.start_soon(Clock(dut.clk, 10, units="us").start())

    await reset(dut)

    # weights are irrelevant here since activations are always zero
    for w in (7, 9, 3, 1):
        await load_weight(dut, w)

    set_activations(dut, 0, 0)
    await ClockCycles(dut.clk, 8)

    assert dut.uo_out.value.integer == 0, (
        f"expected 0 with zero activations, got {dut.uo_out.value.integer}"
    )


@cocotb.test()
async def test_single_row_mac(dut):
    """Row 1 held at 0, row 0 constant -> column outputs settle to
    act_row0 * w00 and act_row0 * w01."""
    dut._log.info("start clock")
    cocotb.start_soon(Clock(dut.clk, 10, units="us").start())

    await reset(dut)

    w00, w01, w10, w11 = 3, 5, 0, 0  # w10/w11 unused since row1 = 0 always
    for w in (w00, w01, w10, w11):
        await load_weight(dut, w)

    act_row0 = 6
    expected_col0 = (act_row0 * w00) & 0xFF
    expected_col1 = (act_row0 * w01) & 0xFF

    set_activations(dut, act_row0, 0)

    # give the array plenty of cycles to reach steady state
    await ClockCycles(dut.clk, 10)

    seen_col0 = False
    seen_col1 = False
    for _ in range(4):
        await RisingEdge(dut.clk)
        uio_out = dut.uio_out.value.integer
        col_id = (uio_out >> 7) & 0x1
        valid = (uio_out >> 6) & 0x1
        value = dut.uo_out.value.integer

        assert valid == 1, "expected valid_out high once the pipeline has filled"

        if col_id == 0:
            assert value == expected_col0, (
                f"column 0: expected {expected_col0}, got {value}"
            )
            seen_col0 = True
        else:
            assert value == expected_col1, (
                f"column 1: expected {expected_col1}, got {value}"
            )
            seen_col1 = True

    assert seen_col0 and seen_col1, "did not observe both columns in the sample window"
