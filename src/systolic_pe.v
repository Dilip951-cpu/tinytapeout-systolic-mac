/*
 * Single processing element (PE) for the 2x2 systolic MAC array.
 *
 * Each clock cycle:
 *   1. the activation and stored weight are optionally masked down to
 *      2 bits (precision_sel = 1) -- this is the "mixed precision" mode,
 *      implemented as operand masking on one shared multiplier rather
 *      than separate multiplier trees per precision
 *   2. if the masked activation is zero, both multiplier operands are
 *      forced to a constant 0 instead of their real values ("operand
 *      isolation" / zero-skip gating) so the multiply/add logic doesn't
 *      switch on a result that's guaranteed to be zero -- this stands in
 *      for literal clock-tree gating, which is riskier to close timing
 *      on for a first small OpenLane/LibreLane flow
 *   3. otherwise: product = a_masked * w_masked, psum_out = psum_in + product
 *   4. the activation is forwarded east (registered), giving the
 *      systolic west-to-east shift
 *
 * Known limitation: psum_out has no saturation logic. Two PEs' 8-bit
 * products summed down a column can in principle exceed 8 bits and
 * wrap around. Left out to save gates for this small TT project --
 * a saturating adder would be the natural v2 addition.
 */

`default_nettype none

module systolic_pe (
    input  wire       clk,
    input  wire       rst_n,          // active low, synchronous
    input  wire       ena,
    input  wire        precision_sel,  // 0 = 4-bit mode, 1 = 2-bit mode
    input  wire        weight_load,    // 1-cycle pulse: latch weight_in
    input  wire [3:0]  weight_in,
    input  wire [3:0]  act_in,         // activation from the west
    input  wire [7:0]  psum_in,        // partial sum from the north
    output reg  [3:0]  act_out,        // activation forwarded east
    output reg  [7:0]  psum_out,       // partial sum forwarded south
    output wire        zero_skip       // debug: high when the MAC datapath is gated this cycle
);

    reg [3:0] weight_reg;

    wire [3:0] a_masked = precision_sel ? {2'b00, act_in[1:0]}     : act_in;
    wire [3:0] w_masked = precision_sel ? {2'b00, weight_reg[1:0]} : weight_reg;

    assign zero_skip = (a_masked == 4'd0);

    wire [3:0] mult_a  = zero_skip ? 4'd0 : a_masked;
    wire [3:0] mult_b  = zero_skip ? 4'd0 : w_masked;
    wire [7:0] product = mult_a * mult_b;

    always @(posedge clk) begin
        if (!rst_n) begin
            weight_reg <= 4'd0;
            act_out    <= 4'd0;
            psum_out   <= 8'd0;
        end else if (ena) begin
            if (weight_load)
                weight_reg <= weight_in;

            act_out <= act_in;

            if (zero_skip)
                psum_out <= psum_in;            // pass-through, adder stays idle
            else
                psum_out <= psum_in + product;
        end
    end

endmodule
