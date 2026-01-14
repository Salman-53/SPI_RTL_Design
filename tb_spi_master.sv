`timescale 1ns/1ps

module tb_spi_master;

    // Parameters
    localparam ADDR_WIDTH  = 14;
    localparam DATA_WIDTH  = 8;
    localparam FRAME_BITS  = 24;

    // DUT I/O
    logic clk;
    logic rst_n;
    logic cmd_valid;
    logic cmd_write;
    logic [ADDR_WIDTH-1:0] cmd_addr;
    logic [DATA_WIDTH-1:0] cmd_wdata;
    logic resp_valid;
    logic [DATA_WIDTH-1:0] resp_rdata;
    logic sclk;
    logic csb;
    logic mosi;
    logic miso;
    logic [1:0] spi_mode;
    integer prescale;

    // Instantiate DUT
    spi_master #(

        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FRAME_BITS(FRAME_BITS)

    ) dut (

        .clk(clk),
        .rst_n(rst_n),
        .cmd_valid(cmd_valid),
        .cmd_write(cmd_write),
        .cmd_addr(cmd_addr),
        .cmd_wdata(cmd_wdata),
        .resp_valid(resp_valid),
        .resp_rdata(resp_rdata),
        .sclk(sclk),
        .csb(csb),
        .mosi(mosi),
        .miso(miso),
        .spi_mode(spi_mode),
        .prescale(prescale)

    );

    // Clock generation: 50 MHz
    initial clk = 0;
    always #10 clk = ~clk;

    // Simple dummy SPI slave model
    // Responds with 0xA5 on read commands
    reg [FRAME_BITS-1:0] slave_shift_reg;
    always @(negedge csb) begin

        // Load response frame into slave shift reg
        // For read: put 0xA5 into the data bits (MSB-first)
        slave_shift_reg <= {FRAME_BITS{1'b0}};
        slave_shift_reg[DATA_WIDTH-1:0] <= 8'hA5; // response data in LSBs

    end

    // Shift logic for slave — sample MOSI, drive MISO
    always @(posedge sclk or negedge sclk) begin

        if (!csb) begin

            // Shift left MSB-first
            slave_shift_reg <= {slave_shift_reg[FRAME_BITS-2:0], 1'b0};
        end

    end

    assign miso = slave_shift_reg[FRAME_BITS-1];

    // Stimulus
    initial begin

        // VCD dumping
        $dumpfile("spi_master_tb.vcd");
        $dumpvars(0, tb_spi_master);

        // Initialize
        rst_n = 0;
        cmd_valid = 0;
        cmd_write = 0;
        cmd_addr  = 0;
        cmd_wdata = 0;
        spi_mode  = 2'b00; // Mode 0
        prescale  = 2;     // very fast for sim

        #50;
        rst_n = 1;
        #50;

        // Issue a read command
        @(posedge clk);
        cmd_addr  = 14'h1234;
        cmd_wdata = 8'h00;
        cmd_write = 0;  // read
        cmd_valid = 1;
        @(posedge clk);
        cmd_valid = 0;

        // Wait for response
        wait (resp_valid);
        $display("Time %0t: Read Response = 0x%0h", $time, resp_rdata);

        // Wait a bit
        repeat (10) @(posedge clk);

        // Change mode to Mode 3
        spi_mode = 2'b11; // CPOL=1, CPHA=1

        // Issue a write command
        @(posedge clk);
        cmd_addr  = 14'h0555;
        cmd_wdata = 8'hCC;
        cmd_write = 1;  // write
        cmd_valid = 1;
        @(posedge clk);
        cmd_valid = 0;

        wait (resp_valid);
        $display("Time %0t: Write Response (dummy) = 0x%0h", $time, resp_rdata);

        // Wait before finish
        repeat (20) @(posedge clk);

        $finish;
    end

endmodule
