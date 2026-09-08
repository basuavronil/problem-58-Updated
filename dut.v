module pipt_cache_hybrid (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [31:0] p_addr,    // Physical address from TLB
    output reg  [31:0] rdata,     // Data read out on a hit
    output reg         hit        // 1 = Cache Hit, 0 = Cache Miss
);

    // Cache Parameters
    localparam LINES = 256;

    // Address Field Extraction
    wire [19:0] ptag  = p_addr[31:12]; // Physical Tag (20 bits)
    wire [7:0]  index = p_addr[11:4];  // Index (8 bits)

    // Internal Cache Arrays
    reg [19:0] tag_ram  [0:LINES-1];
    reg [31:0] data_ram [0:LINES-1];
    reg [LINES-1:0] valid_bit;

    // Load initial data at startup
    initial begin
        $readmemh("tags.hex", tag_ram);
        $readmemh("data.hex", data_ram);
    end

    // 1. Sequential Write / Line Fill Path
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < LINES; i = i + 1) begin
                valid_bit[i] <= 1'b1; // Mark pre-loaded entries valid
            end
        end else if (wr_en) begin
            tag_ram[index]   <= ptag;
            valid_bit[index] <= 1'b1;
        end
    end

    // 2. Hybrid Read & Tag Compare Logic
    // Synchronous Memory Lookup + Instant Combinational Compare
    always @(*) begin
        hit   = valid_bit[index] && (tag_ram[index] == ptag);
        rdata = data_ram[index];
    end

endmodule
