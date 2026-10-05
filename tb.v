`timescale 1ns/1ps

module tb_pipt_cache_hybrid;

    reg clk = 0;
    reg rst_n;
    reg [31:0] p_addr;
    wire [31:0] rdata;
    wire hit;

    integer errors = 0;

    pipt_cache_hybrid dut (
        .clk(clk), .rst_n(rst_n), .p_addr(p_addr), .rdata(rdata), .hit(hit)
    );

    always #5 clk = ~clk;

    // Known-good values extracted from tags.hex / data.hex (index 5 and 200)
    localparam [19:0] TAG5   = 20'h47718;
    localparam [19:0] TAG200 = 20'h19e6b;

    task check(input exp_hit, input [31:0] exp_data, input use_data, input [255:0] label);
        begin
            #1;
            if (hit !== exp_hit) begin
                $display("ERROR [%0s]: expected hit=%0d, got hit=%0d", label, exp_hit, hit);
                errors = errors + 1;
            end else if (use_data && exp_hit && rdata !== exp_data) begin
                $display("ERROR [%0s]: expected rdata=%0h, got rdata=%0h", label, exp_data, rdata);
                errors = errors + 1;
            end else begin
                $display("OK [%0s]: hit=%0d rdata=%0h", label, hit, rdata);
            end
        end
    endtask

    initial begin
        rst_n = 0;
        p_addr = {TAG5, 8'd5, 2'd0, 2'd0};  // index 5, word 0, correct tag
        repeat (2) @(posedge clk);
        // 1. During reset, must always miss even though tag/index are correct
        check(1'b0, 32'h0, 1'b0, "miss during reset despite correct tag");

        #1; rst_n = 1;
        @(posedge clk);

        // 2. After reset release, correct tag at index 5, word 0 -> hit, correct data
        p_addr = {TAG5, 8'd5, 2'd0, 2'd0};
        check(1'b1, 32'hbdc14f1f, 1'b1, "hit index5 word0");

        // 3. Same line, word 2 -> hit, different correct data
        p_addr = {TAG5, 8'd5, 2'd2, 2'd0};
        check(1'b1, 32'he767dcea, 1'b1, "hit index5 word2");

        // 4. Same index, WRONG tag -> must miss
        p_addr = {20'h00000, 8'd5, 2'd0, 2'd0};
        check(1'b0, 32'h0, 1'b0, "miss wrong tag at index5");

        // 5. Different index (200), correct tag, word 0 -> hit, correct data
        p_addr = {TAG200, 8'd200, 2'd0, 2'd0};
        check(1'b1, 32'h92fa675f, 1'b1, "hit index200 word0");

        if (errors == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d TEST(S) FAILED ***", errors);

        $finish;
    end

endmodule
