`timescale 1ns/1ps

module tb_pipt_cache_hybrid;

    // Testbench Signals
    reg        clk;
    reg        rst_n;
    reg        wr_en;
    reg [31:0] p_addr;
    wire [31:0] rdata;
    wire        hit;

    // Instantiate the Hybrid PIPT Cache
    pipt_cache_hybrid uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .p_addr(p_addr),
        .rdata(rdata),
        .hit(hit)
    );

    // Clock Generation (10ns period -> 100MHz clock)
    always #5 clk = ~clk;

    initial begin
        // Initialize Signals
        clk    = 0;
        rst_n  = 0;
        wr_en  = 0;
        p_addr = 32'h00000000;

        // Apply Reset
        #15;
        rst_n = 1;
        #10;

        $display("--------------------------------------------------");
        $display("       STARTING PIPT CACHE HYBRID TESTS           ");
        $display("--------------------------------------------------");

        // =========================================================
        // Test 1: Hit Test (Access pre-loaded Index 0)
        // Expected Tag: 0x00012 | Index: 0x00 | Expected Data: 12345678
        // Address Format: [31:12] Tag = 00012 | [11:4] Index = 00 | [3:0] Offset = 0
        // =========================================================
        p_addr = 32'h00012000;
        #10;
        if (hit && (rdata == 32'h12345678)) begin
            $display("[PASS] TEST 1 (Hit): Addr=%h -> Hit=%b, Data=%h", p_addr, hit, rdata);
        end else begin
            $display("[FAIL] TEST 1 (Hit): Addr=%h -> Hit=%b, Data=%h (Expected: 12345678)", p_addr, hit, rdata);
        end

        // =========================================================
        // Test 2: Miss Test (Wrong Tag at Index 2)
        // Index 2 has pre-loaded Tag 0x000AB. We send Tag 0x99999.
        // Address Format: [31:12] Tag = 99999 | [11:4] Index = 02 | [3:0] Offset = 0
        // =========================================================
        p_addr = 32'h99999020;
        #10;
        if (!hit) begin
            $display("[PASS] TEST 2 (Miss): Addr=%h -> Hit=%b (Correct Miss)", p_addr, hit);
        end else begin
            $display("[FAIL] TEST 2 (Miss): Addr=%h -> Hit=%b (Unexpected Hit)", p_addr, hit);
        end

        // =========================================================
        // Test 3: Write Operation (Update Tag at Index 2)
        // Overwrite Index 2's Tag with 0x99999 on posedge clk
        // =========================================================
        $display("\n--- Writing New Tag (0x99999) to Index 0x02 ---");
        wr_en = 1;
        p_addr = 32'h99999020;
        #10; // Trigger clock edge write
        wr_en = 0;

        // =========================================================
        // Test 4: Hit Test After Write
        // The previously missing address should now be a HIT
        // =========================================================
        p_addr = 32'h99999020;
        #10;
        if (hit) begin
            $display("[PASS] TEST 4 (Hit After Write): Addr=%h -> Hit=%b, Data=%h", p_addr, hit, rdata);
        end else begin
            $display("[FAIL] TEST 4 (Hit After Write): Addr=%h -> Hit=%b", p_addr, hit);
        end

        $display("--------------------------------------------------");
        $display("               TESTS COMPLETED                    ");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
