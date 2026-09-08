module pipt_cache_hybrid (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] p_addr,    // Physical Address from TLB
    output reg  [31:0] rdata,     // Cached Data Output
    output reg         hit        // Hit / Miss Signal
);

    localparam LINES = 256;

    wire [19:0] ptag  = p_addr[31:12];
    wire [7:0]  index = p_addr[11:4];

    reg [19:0] tag_ram  [0:LINES-1];
    reg [31:0] data_ram [0:LINES-1];
    reg [LINES-1:0] valid_bit;

    initial begin
        $readmemh("tags.hex", tag_ram);
        $readmemh("data.hex", data_ram);
    end

    // Power-on protection: Force valid bits to 0 during reset
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_bit <= {LINES{1'b0}}; // Suppress hit signal on reset
        end else begin
            valid_bit <= {LINES{1'b1}}; // Enable valid bits after reset release
        end
    end

    // Combinational lookup gated by the valid bit
    always @(*) begin
        hit   = valid_bit[index] && (tag_ram[index] == ptag);
        rdata = data_ram[index];
    end

endmodule
