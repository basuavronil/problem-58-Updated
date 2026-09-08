`timescale 1ns/1ps

module tb_pipt_cache_hybrid;

    // Testbench Signals
    reg        clk;
    reg        rst_n;
    reg [31:0] p_addr;
    wire [31:0] rdata;
    wire        hit;

    // Instantiate Unit Under Test (UUT)
    pipt_cache_hybrid uut (
        .clk(clk),
        .rst_n(rst_n),
        .p_addr(p_addr),
        .rdata(rdata),
        .hit(hit)
    );

    // Clock Generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // -------------------------------------------------------------
        // Step 1: Initialize Inputs
        // -------------------------------------------------------------
        clk    = 0;
        rst_n  = 0;
        p_addr = 32'h00012000; // Target Index 0 (Pre-loaded Tag: 0x00012)

        $display("--------------------------------------------------");
        $display("   STARTING PIPT CACHE RESET & LOOKUP TESTBENCH   ");
        $display("--------------------------------------------------");

        // -------------------------------------------------------------
        // Step 2: Verify Reset Protection (valid_bit = 0)
        // -------------------------------------------------------------
        #7; // Inside active reset window
        if (hit == 1'b0) begin
            $display("[PASS] During Reset: Hit is suppressed (hit = %b)", hit);
        end else begin
            $display("[FAIL] During Reset: Hit asserted unexpectedly (hit = %b)", hit);
        end

        // -------------------------------------------------------------
        // Step 3: Release Reset & Verify Valid Operations
        // -------------------------------------------------------------
        #8;
        rst_n = 1; // De-assert reset (valid_bit becomes 1 on next posedge clk)
        #10;       // Wait for 1 clock tick

        // Test 1: Hit Check at Index 0 (Tag 0x00012)
        p_addr = 32'h00012000;
        #5; // Allow combinational logic to settle
        if (hit && (rdata == 32'h12345678)) begin
            $display("[PASS] Test 1 (Hit): Addr=%h -> Hit=%b, Data=%h", p_addr, hit, rdata);
        end else begin
            $display("[FAIL] Test 1 (Hit): Addr=%h -> Hit=%b, Data=%h (Expected: 12345678)", p_addr, hit, rdata);
        end

        // Test 2: Miss Check at Index 2 (Wrong Tag 0x99999)
        p_addr = 32'h99999020;
        #10;
        if (!hit) begin
            $display("[PASS] Test 2 (Miss): Addr=%h -> Hit=%b", p_addr, hit);
        end else begin
            $display("[FAIL] Test 2 (Miss): Addr=%h -> Hit=%b (Unexpected Hit)", p_addr, hit);
        end

        // Test 3: Hit Check at Index 2 (Correct Tag 0x000AB)
        p_addr = 32'h000AB020;
        #10;
        if (hit && (rdata == 32'hDEADBEEF)) begin
            $display("[PASS] Test 3 (Hit): Addr=%h -> Hit=%b, Data=%h", p_addr, hit, rdata);
        end else begin
            $display("[FAIL] Test 3 (Hit): Addr=%h -> Hit=%b, Data=%h (Expected: DEADBEEF)", p_addr, hit, rdata);
        end

        $display("--------------------------------------------------");
        $display("               TESTS COMPLETED                    ");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
