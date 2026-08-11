/*
 * Reconfigurable mixed-precision 2x2 systolic MAC array for Tiny Tapeout.
 *
 * - 2x2 weight-stationary array of systolic_pe processing elements
 * - 4-bit or 2-bit operand precision, selected globally via precision_sel
 * - zero-operand skip (operand isolation) inside each PE -- see systolic_pe.v
 * - weights are preloaded once via a 4-pulse load sequence, then two
 *   4-bit activation streams (one per row) flow through the array every
 *   clock cycle
 *
 * Pinout summary (see docs/info.md / info.yaml for the authoritative copy):
 *   ui_in[3:0]  = act_row0_in   (activation into PE(0,0))
 *   ui_in[7:4]  = act_row1_in   (activation into PE(1,0))
 *   uio_in[3:0] = weight_in     (value to load on the next weight_load pulse)
 *   uio_in[4]   = weight_load   (1-cycle pulse, loads PE(0,0)->PE(0,1)->
 *                                PE(1,0)->PE(1,1) in that order, once per pulse)
 *   uio_in[5]   = precision_sel (0 = 4-bit mode, 1 = 2-bit mode)
 *   uio_in[7:6] = unused
 *   uo_out[7:0] = psum_out      (column 0 or column 1 partial sum,
 *                                alternating every clock cycle)
 *   uio_out[7]  = col_id        (0 = column 0 is on uo_out this cycle, 1 = column 1)
 *   uio_out[6]  = valid_out     (goes high once the pipeline has filled)
 *   uio_out[5:0]= unused, driven low
 */

`default_nettype none

module tt_um_dilip951_cpu_systolic_array (
    input  wire [7:0] ui_in,    // dedicated inputs
    output wire [7:0] uo_out,   // dedicated outputs
    input  wire [7:0] uio_in,   // IOs: input path
    output wire [7:0] uio_out,  // IOs: output path
    output wire [7:0] uio_oe,   // IOs: enable path (1 = drive as output)
    input  wire        ena,     // high when the design is powered/selected
    input  wire        clk,
    input  wire        rst_n    // active low, synchronous
);

    // ---------------- input decode ----------------
    wire [3:0] act_row0_in    = ui_in[3:0];
    wire [3:0] act_row1_in    = ui_in[7:4];

    wire [3:0] weight_in      = uio_in[3:0];
    wire       weight_load_i  = uio_in[4];
    wire       precision_sel  = uio_in[5];

    // ---------------- weight-load sequencer ----------------
    // Present weight_in and pulse weight_load once per PE, in the order
    // PE(0,0), PE(0,1), PE(1,0), PE(1,1). load_idx tracks which PE is next.
    reg       prev_wl;
    reg [1:0] load_idx;

    always @(posedge clk) begin
        if (!rst_n) begin
            prev_wl  <= 1'b0;
            load_idx <= 2'd0;
        end else if (ena) begin
            prev_wl <= weight_load_i;
            if (weight_load_i && !prev_wl)
                load_idx <= load_idx + 2'd1;
        end
    end

    wire       wl_edge = weight_load_i && !prev_wl;
    wire [3:0] pe_ld   = wl_edge ? (4'b0001 << load_idx) : 4'b0000;

    // ---------------- PE array ----------------
    wire [3:0] pe00_act_out, pe01_act_out, pe10_act_out, pe11_act_out;
    wire [7:0] pe00_psum_out, pe01_psum_out, pe10_psum_out, pe11_psum_out;
    // debug-only: visible in simulation waveforms, not brought to a top pin
    wire       pe00_zs, pe01_zs, pe10_zs, pe11_zs;

    systolic_pe pe00 (
        .clk(clk), .rst_n(rst_n), .ena(ena),
        .precision_sel(precision_sel),
        .weight_load(pe_ld[0]), .weight_in(weight_in),
        .act_in(act_row0_in), .psum_in(8'd0),
        .act_out(pe00_act_out), .psum_out(pe00_psum_out), .zero_skip(pe00_zs)
    );

    systolic_pe pe01 (
        .clk(clk), .rst_n(rst_n), .ena(ena),
        .precision_sel(precision_sel),
        .weight_load(pe_ld[1]), .weight_in(weight_in),
        .act_in(pe00_act_out), .psum_in(8'd0),
        .act_out(pe01_act_out), .psum_out(pe01_psum_out), .zero_skip(pe01_zs)
    );

    systolic_pe pe10 (
        .clk(clk), .rst_n(rst_n), .ena(ena),
        .precision_sel(precision_sel),
        .weight_load(pe_ld[2]), .weight_in(weight_in),
        .act_in(act_row1_in), .psum_in(pe00_psum_out),
        .act_out(pe10_act_out), .psum_out(pe10_psum_out), .zero_skip(pe10_zs)
    );

    systolic_pe pe11 (
        .clk(clk), .rst_n(rst_n), .ena(ena),
        .precision_sel(precision_sel),
        .weight_load(pe_ld[3]), .weight_in(weight_in),
        .act_in(pe10_act_out), .psum_in(pe01_psum_out),
        .act_out(pe11_act_out), .psum_out(pe11_psum_out), .zero_skip(pe11_zs)
    );

    // ---------------- output streaming ----------------
    // Column 0 and column 1 partial sums can't both fit on the 8 uo_out
    // pins at once, so they're time-multiplexed one column per cycle.
    reg       out_sel;
    reg [1:0] valid_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            out_sel   <= 1'b0;
            valid_cnt <= 2'd0;
        end else if (ena) begin
            out_sel <= ~out_sel;
            if (valid_cnt != 2'd3)
                valid_cnt <= valid_cnt + 2'd1;
        end
    end

    wire pipeline_valid = (valid_cnt == 2'd3);

    assign uo_out  = out_sel ? pe11_psum_out : pe10_psum_out;
    assign uio_out = {out_sel, pipeline_valid, 6'b0};
    assign uio_oe  = 8'b1100_0000; // uio[7:6] outputs, uio[5:0] inputs

    // keep lint quiet about intentionally-unused bits/wires
    wire _unused = &{uio_in[7:6], pe00_zs, pe01_zs, pe10_zs, pe11_zs, 1'b0};

endmodule
