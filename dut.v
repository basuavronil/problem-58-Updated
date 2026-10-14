// skid_buffer.v : valid/ready pipeline stage with a skid register (fixed 33-bit data)
module skid_buffer (
    input  wire        clk,
    input  wire        rst_n,

    // upstream side (master -> buffer)
    input  wire        s_valid,
    output wire        s_ready,
    input  wire [32:0] s_data,

    // downstream side (buffer -> slave)
    output reg         m_valid,
    input  wire        m_ready,
    output reg  [32:0] m_data       // main register, the ONLY thing that drives the output
);

    reg        skid_valid;
    reg [32:0] skid_data;

    // Registered backpressure: upstream learns the buffer is full one cycle late.
    assign s_ready = !skid_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid    <= 1'b0;
            skid_valid <= 1'b0;
        end else begin
            if (m_ready || !m_valid) begin
                // Main is empty, or the slave is taking its beat this cycle.
                if (skid_valid) begin
                    // Beat A leaves main; beat B moves from skid into main on the same edge.
                    m_data     <= skid_data;
                    m_valid    <= 1'b1;
                    skid_valid <= 1'b0;
                end else begin
                    // Normal flow-through.
                    m_data  <= s_data;
                    m_valid <= s_valid;
                end
            end else if (s_valid && s_ready) begin
                // Stall: main holds beat A, slave not ready, beat B arrives -> park in skid.
                skid_data  <= s_data;
                skid_valid <= 1'b1;
            end
            // else: main full, skid full, slave not ready -> hold everything.
        end
    end

endmodule
