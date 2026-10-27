// ============================================================================
// pipt_cache_hybrid.v  (corrected, original port list preserved)
//   
// Scope note: with no fill/write port on this interface, tag_ram and
// data_ram can only ever be populated once, via $readmemh at elaboration
// time. That means every line is loaded (or not) identically and at the
// same time - there is no mechanism by which some lines could be valid
// and others not. The corrections below reflect that scope honestly,
// rather than adding ports that weren't part of the original interface.
//
// Fixes applied to the original version:
//  1. valid_bit was an array of 256 individual flip-flops, all driven by
//     the same unconditional reset/set logic in a for-loop using a
//     non-blocking assignment - a pattern Verilator flags as not broadly
//     synthesis-safe. Since there is no fill port, every line's validity
//     is necessarily identical at all times (all invalid during reset,
//     all valid once reset releases and the $readmemh-loaded contents are
//     trusted). valid_bit is therefore collapsed to a single flip-flop,
//     which is both synthesis-safe and a more honest reflection of what
//     this interface can actually support.
//  2. The address breakdown implied a 16-byte line (p_addr[3:0] as block
//     offset) but only one 32-bit word was stored per line, so 12 of
//     every 16 addressable bytes were never actually stored or returned.
//     data_ram is now a proper LINES x 4-word array, with p_addr[3:2]
//     selecting the word within the line, consistent with the existing
//     p_addr[11:4] index field.
// ============================================================================
`timescale 1ns/1ps
module pipt_cache_hybrid (
    input  wire        clk,
    input  wire        rst_n,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [31:0] p_addr,    // Physical Address from TLB (byte [1:0] unused - word-aligned)
    /* verilator lint_on UNUSEDSIGNAL */
    output reg  [31:0] rdata,     // Cached Data Output
    output reg          hit        // Hit / Miss Signal
);
    localparam LINES = 256;
    wire [19:0] ptag  = p_addr[31:12];
    wire [7:0]  index = p_addr[11:4];
    wire [1:0]  woff  = p_addr[3:2];   // word-within-line (4 words = 16B line)
    reg [19:0] tag_ram  [0:LINES-1];
    reg [31:0] data_ram [0:LINES-1][0:3];
    reg        valid;   // single flag: see scope note above - with no fill
                         // port, every line's validity is necessarily the
                         // same at all times, so one flip-flop is both
                         // sufficient and synthesis-safe (no looped
                         // non-blocking array assignment required).
    integer i, j;
    initial begin
        for (i = 0; i < LINES; i = i + 1) begin
            tag_ram[i] = 20'd0;
            for (j = 0; j < 4; j = j + 1)
                data_ram[i][j] = 32'd0;
        end
        $readmemh("tags.hex", tag_ram);
        $readmemh("data.hex", data_ram);
    end
    // Power-on protection: hold the cache invalid through reset, so no
    // lookup can report a hit before the $readmemh-loaded contents are
    // guaranteed settled; release to valid once reset deasserts.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid <= 1'b0;
        else
            valid <= 1'b1;
    end
    // Combinational lookup gated by the valid flag
    always @(*) begin
        hit   = valid && (tag_ram[index] == ptag);
        rdata = data_ram[index][woff];
    end
endmodule
