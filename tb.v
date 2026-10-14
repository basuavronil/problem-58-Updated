`timescale 1ns/1ps
module tb_skid_buffer;
    reg         clk = 0, rst_n = 0;
    reg         s_valid = 0;
    wire        s_ready;
    reg  [32:0] s_data = 0;
    wire        m_valid;
    reg         m_ready = 0;
    wire [32:0] m_data;

    skid_buffer dut (.clk(clk), .rst_n(rst_n),
        .s_valid(s_valid), .s_ready(s_ready), .s_data(s_data),
        .m_valid(m_valid), .m_ready(m_ready), .m_data(m_data));

    always #5 clk = ~clk;

    // ---------------- scoreboard: FIFO of accepted beats ----------------
    reg [32:0] sb [0:4095];
    integer wr_ptr = 0, rd_ptr = 0, errors = 0, sent = 0;

    always @(posedge clk) if (rst_n) begin
        if (s_valid && s_ready) begin           // beat accepted from master
            sb[wr_ptr % 4096] <= s_data;
            wr_ptr <= wr_ptr + 1;
        end
        if (m_valid && m_ready) begin           // beat taken by slave
            if (rd_ptr >= wr_ptr) begin
                $display("ERROR t=%0t: output beat with nothing sent", $time);
                errors = errors + 1;
            end else if (m_data !== sb[rd_ptr % 4096]) begin
                $display("ERROR t=%0t: got %h expected %h (order/data)",
                         $time, m_data, sb[rd_ptr % 4096]);
                errors = errors + 1;
            end
            rd_ptr <= rd_ptr + 1;
        end
        // output must hold stable while stalled
        if (m_valid && !m_ready) begin
            #1;
            if (!m_valid) begin
                $display("ERROR t=%0t: m_valid dropped during stall", $time);
                errors = errors + 1;
            end
        end
    end

    // ---------------- helpers ----------------
    task send(input [32:0] d);
        begin
            s_valid <= 1; s_data <= d;
            @(posedge clk);
            while (!s_ready) @(posedge clk);   // hold until accepted
            s_valid <= 0;
        end
    endtask

    integer k;
    initial begin
        $dumpfile("skid.vcd"); $dumpvars(0, tb_skid_buffer);
        repeat (3) @(posedge clk);
        rst_n <= 1;
        @(posedge clk);

        // ---- TEST 1: directed scenario from the interview ----
        // Slave not ready. A fills main, B fills skid, then slave asserts ready.
        $display("TEST 1: directed stall A/B");
        m_ready <= 0;
        s_valid <= 1; s_data <= 33'h1_AAAA_AAAA;     // beat A
        @(posedge clk);                               // A -> main
        s_data  <= 33'h0_BBBB_BBBB;                   // beat B
        @(posedge clk);                               // B -> skid
        s_valid <= 0;
        #1;
        if (s_ready !== 1'b0) begin $display("ERROR: s_ready should be low (skid full)"); errors = errors + 1; end
        if (m_data !== 33'h1_AAAA_AAAA) begin $display("ERROR: main should hold A"); errors = errors + 1; end
        repeat (3) @(posedge clk);                    // stay stalled, A must hold
        #1;
        if (m_data !== 33'h1_AAAA_AAAA) begin $display("ERROR: A changed during stall"); errors = errors + 1; end
        m_ready <= 1;                                 // slave asserts ready
        @(posedge clk); #1;                           // A consumed, B moves into main
        if (m_data !== 33'h0_BBBB_BBBB) begin $display("ERROR: B should now be in main, got %h", m_data); errors = errors + 1; end
        if (s_ready !== 1'b1) begin $display("ERROR: s_ready should be high again"); errors = errors + 1; end
        @(posedge clk);
        m_ready <= 0;
        repeat (3) @(posedge clk);

        // ---- TEST 2: full throughput, slave always ready ----
        $display("TEST 2: streaming, no stalls");
        m_ready <= 1;
        for (k = 0; k < 20; k = k + 1) send({1'b0, 32'h1000 + k});
        repeat (4) @(posedge clk);

        // ---- TEST 3: random backpressure on both sides ----
        $display("TEST 3: random traffic");
        fork
            begin : master
                for (k = 0; k < 1000; k = k + 1) begin
                    if ($random % 3 == 0) begin s_valid <= 0; @(posedge clk); end
                    send({$random, $random});
                end
            end
            begin : slave
                repeat (6000) begin
                    m_ready <= ($random % 4 != 0) ? 1'b1 : 1'b0;
                    @(posedge clk);
                end
            end
        join
        m_ready <= 1;
        repeat (10) @(posedge clk);

        if (rd_ptr != wr_ptr) begin
            $display("ERROR: %0d beats sent, %0d received", wr_ptr, rd_ptr);
            errors = errors + 1;
        end
        if (errors == 0) $display("PASS: %0d beats, in order, no loss", rd_ptr);
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin #500000; $display("TIMEOUT"); $finish; end
endmodule
