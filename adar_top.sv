`timescale 1ns/1ps
module adar_top (
    input logic clk,
    input logic rst_n,
    // physical SPI pins
    output logic sclk,
    output logic csb,
    output logic mosi,
    input  logic miso
);

    // instantiate data memory
    logic cmd_valid;
    logic cmd_write;
    logic [6:0] cmd_addr; // your data module uses 7-bit addr (0..127)
    logic [23:0] cmd_wdata24; // but our spi_master uses 14/8; we'll present lower byte to it
    logic resp_valid;
    logic [23:0] resp_rdata24;

    // We'll use the data management module with DATA_WIDTH=24
    logic mem_resp_valid;
    logic [23:0] mem_resp_rdata;

    data_mgmt_mem_if #(.ADDR_WIDTH(7), .DATA_WIDTH(24)) data_if (
        .clk(clk), .rst_n(rst_n),
        .cmd_valid(cmd_valid),
        .cmd_write(cmd_write),
        .cmd_addr(cmd_addr),
        .cmd_wdata(cmd_wdata24[23:0]),
        .resp_valid(mem_resp_valid),
        .resp_rdata(mem_resp_rdata),
        .det_update_valid(), .det_index(), .det_value(),
        .temp_update_valid(), .temp_raw_value(),
        .mem_busy()
    );

    // SPI master instance (talks to ADAR1000)
    logic spi_cmd_valid;
    logic spi_cmd_write;
    logic [13:0] spi_cmd_addr;
    logic [7:0]  spi_cmd_wdata;
    logic spi_resp_valid;
    logic [7:0] spi_resp_rdata;
    logic [1:0] spi_mode;
    integer prescale = 4;

    spi_master #(.ADDR_WIDTH(14), .DATA_WIDTH(8)) spi0 (
        .clk(clk), .rst_n(rst_n),
        .cmd_valid(spi_cmd_valid),
        .cmd_write(spi_cmd_write),
        .cmd_addr(spi_cmd_addr),
        .cmd_wdata(spi_cmd_wdata),
        .resp_valid(spi_resp_valid),
        .resp_rdata(spi_resp_rdata),
        .sclk(sclk), .csb(csb), .mosi(mosi), .miso(miso),
        .spi_mode(spi_mode), .prescale(prescale)
    );

    // Simple controller FSM: demonstration only
    typedef enum logic [2:0] {T_IDLE, T_WRITE_BEAMS, T_READ_DET0, T_READ_TEMP, T_WAIT_RESP} tstate_t;
    tstate_t tstate, tnext;
    logic [6:0] beam_idx;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tstate <= T_IDLE; beam_idx <= 0;
            spi_cmd_valid <= 0;
            cmd_valid <= 0;
            spi_mode <= 2'b00;
        end else begin
            tstate <= tnext;
            // simple sequential operations
            if (tstate == T_WRITE_BEAMS) begin
                // read beam data from memory then write to ADAR
                if (!mem_resp_valid) begin
                    // ask data_if for beam idx (read)
                    cmd_valid <= 1;
                    cmd_write <= 0;
                    cmd_addr <= beam_idx;
                    // After one cycle data_if will respond (mem_resp_valid)
                end else begin
                    cmd_valid <= 0;
                    // mem_resp_rdata now has 24-bit beam word.
                    // Break into ADAR register writes as needed. For demo send lower 8-bit to address base+idx
                    spi_cmd_valid <= 1;
                    spi_cmd_write <= 1;
                    spi_cmd_addr <= 14'h1000 + beam_idx; // example address mapping
                    spi_cmd_wdata <= mem_resp_rdata[7:0]; // send low byte
                end
            end else if (tstate == T_READ_DET0) begin
                // Example: trigger ADC conversion (write 0x032), then read 0x033
                if (!spi_cmd_valid && !spi_resp_valid) begin
                    // start conversion register write
                    spi_cmd_valid <= 1;
                    spi_cmd_write <= 1;
                    spi_cmd_addr <= 14'h0032; // ADC control reg
                    spi_cmd_wdata <= 8'h20;   // set ST_CONV bit
                end
            end else begin
                // default
                cmd_valid <= 0;
                spi_cmd_valid <= 0;
            end

            // clear spi_cmd_valid after one cycle (edge handshake)
            if (spi_cmd_valid) spi_cmd_valid <= 0;
            if (cmd_valid) cmd_valid <= 0;
        end
    end

    always_comb begin
        tnext = tstate;
        case (tstate)
            T_IDLE: tnext = T_WRITE_BEAMS;
            T_WRITE_BEAMS: if (beam_idx == 7'd120) tnext = T_READ_DET0;
            T_READ_DET0: if (spi_resp_valid) tnext = T_READ_TEMP;
            T_READ_TEMP: if (spi_resp_valid) tnext = T_IDLE;
            default: tnext = T_IDLE;
        endcase
    end

endmodule
