`timescale 1ns / 1ps

module tb_prbs;

  reg        clk;
  reg        rst;
  reg        load;
  reg  [7:0] initial_seed;
  wire       prbs_out;

  // Instantiate the PRBS module
  prbs uut (
    .clk          (clk),
    .rst          (rst),
    .load         (load),
    .initial_seed (initial_seed),
    .prbs_out     (prbs_out)
  );

  // Clock generation (100 MHz)
  always #5 clk = ~clk;

  initial begin
    // Set up VCD waveform dumping
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_prbs);

    // Set up continuous monitoring of signals to terminal output
    $monitor("Time=%0t | rst=%b load=%b seed=0h%h | LFSR=8'b%b (0h%h) | prbs_out=%b", 
             $time, rst, load, initial_seed, uut.lfsr, uut.lfsr, prbs_out);

    // Initial signal states
    clk = 0;
    rst = 0;
    load = 0;
    initial_seed = 8'hA5;

    // Apply active-low reset release and seed load
    #20 rst = 1;
    #10 load = 1;
    #10 load = 0;

    // Run for 200 ns to observe the output sequence
    #200;
    $finish;
  end

endmodule
