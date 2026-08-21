Reconfigurable Mixed-Precision 2×2 Weight-Stationary Systolic MAC Array

Tiny Tapeout submission, SkyWater 130nm, TTSKY26c shuttle

Read the full project documentation
Verification summary and report
What is this?

This project implements a 2×2 weight-stationary systolic array of multiply-accumulate (MAC) processing elements that can switch between two numeric precisions at runtime.

Each processing element holds a stationary weight and streams activations through the array, accumulating partial sums as data flows from PE to PE — the classic systolic dataflow used in most modern NPU/TPU-style accelerators, scaled down to fit a single TinyTapeout tile.

Rather than instantiating separate multipliers for 4-bit and 2-bit operation, precision switching is implemented through a shared masked multiplier: the same multiplier hardware is reused for both modes, with input masking gating the unused bits when running the lower precision. A zero-operand skip mechanism gates the accumulate path whenever an operand is zero, avoiding unnecessary switching activity on those cycles.

Research contribution: 2×2 systolic arrays have appeared before on TinyTapeout, but this specific combination — runtime-reconfigurable mixed precision via a shared masked multiplier, weight-stationary dataflow, and zero-operand skip gating, all within a single fixed silicon budget — has not been replicated elsewhere in the shuttle. A feature-comparison table against prior systolic-array submissions is included in the documentation.

Design summary
Top module: tt_um_dilip951_cpu_systolic_array
Real device count: 608 standard cells (post place-and-route, sky130_fd_sc_hd), 62 flip-flops
Die area: ~117 × 128 µm
PDK: sky130A (fixed by the TTSKY26c shuttle)
Verified: DRC, LVS, and antenna checks clean via LibreLane 3.0.5 through GitHub Actions CI (gds, precheck 15/15, gl_test, viewer all passing), independently cross-checked with an OpenLane2 Colab flow — matching flip-flop count, die area, and a clean LVS result
Verification: cocotb testbench, both functional tests passing
What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

Resources
FAQ
Digital design lessons
Learn how semiconductors work
Join the community
Build your design locally
