`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Masooma
// 
// Create Date: 08/09/2025 11:27:44 PM
// Design Name: 
// Module Name: data_mgmt_mem_if
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
// Simple parameterized Data Management & Memory Interface for ADAR1000
// - Stores N_BEAM_POS beam positions (default 128 to cover 121 positions)
// - Provides a clean command interface for the SPI master controller
// - Includes registers to hold 4 RF detector readings and 1 temperature raw reading
// - Read/write handshake is simple: cmd_valid, cmd_type, addr, wdata -> resp_valid, rdata
// - Parameterized data width to match ADAR1000 word size (set as needed)
//////////////////////////////////////////////////////////////////////////////////

module data_mgmt_mem_if #(
    parameter ADDR_WIDTH = 7,        // 2^7 = 128 entries (>=121)
    parameter DATA_WIDTH = 24        // bits per stored beam-position word
)(
    input  logic                     clk,
    input  logic                     rst_n,

    // Command interface from SPI master
    input  logic                     cmd_valid,   // pulse high when a command is presented
    input  logic                     cmd_write,   // 1 = write, 0 = read
    input  logic [ADDR_WIDTH-1:0]    cmd_addr,    // address / register index
    input  logic [DATA_WIDTH-1:0]    cmd_wdata,   // write data
    output logic                     resp_valid,  // response ready
    output logic [DATA_WIDTH-1:0]    resp_rdata,  // read data

    // External update interface
    input  logic                     det_update_valid,
    input  logic [1:0]               det_index,   // 0..3 for four RF detectors
    input  logic [DATA_WIDTH-1:0]    det_value,

    input  logic                     temp_update_valid,
    input  logic [DATA_WIDTH-1:0]    temp_raw_value,

    // Status
    output logic                     mem_busy
);

    // Internal memory for beam positions
    localparam MEM_DEPTH = (1 << ADDR_WIDTH);
    logic [DATA_WIDTH-1:0] beam_mem [0:MEM_DEPTH-1];

    // Small register file for detectors and temp
    logic [DATA_WIDTH-1:0] rf_detectors [0:3];
    logic [DATA_WIDTH-1:0] temp_raw_reg;

    // FSM states
    typedef enum logic [1:0] {IDLE, ACCEPT, RESP} state_t;
    state_t state, next_state;

    // mem_busy when not idle
    assign mem_busy = (state != IDLE);

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE:   if (cmd_valid) next_state = ACCEPT;
            ACCEPT: next_state = RESP;
            RESP:   next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
  
  
    integer i;
    // Main sequential process (single always_ff drives resp_valid & resp_rdata)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            resp_valid <= 1'b0;
            resp_rdata <= '0;
            for (i = 0; i < MEM_DEPTH; i++) beam_mem[i] <= '0;
            for (i = 0; i < 4; i++) rf_detectors[i] <= '0;
            temp_raw_reg <= '0;
        end else begin
            state <= next_state;

            // Default: clear resp_valid when leaving RESP
            if (state == RESP && next_state == IDLE)
                resp_valid <= 1'b0;

            // Handle external detector/temp updates
            if (det_update_valid)
                rf_detectors[det_index] <= det_value;

            if (temp_update_valid)
                temp_raw_reg <= temp_raw_value;

            case (state)
                ACCEPT: begin
                    if (cmd_write) begin
                        // Write command
                        if (cmd_addr < 121) begin
                            beam_mem[cmd_addr] <= cmd_wdata;
                            resp_rdata <= cmd_wdata; // echo back
                        end else begin
                            unique case (cmd_addr)
                                7'd121: rf_detectors[0] <= cmd_wdata;
                                7'd122: rf_detectors[1] <= cmd_wdata;
                                7'd123: rf_detectors[2] <= cmd_wdata;
                                7'd124: rf_detectors[3] <= cmd_wdata;
                                7'd125: temp_raw_reg    <= cmd_wdata;
                                default: ;
                            endcase
                            resp_rdata <= cmd_wdata; // echo
                        end
                    end else begin
                        // Read command
                        if (cmd_addr < 121) begin
                            resp_rdata <= beam_mem[cmd_addr];
                        end else begin
                            unique case (cmd_addr)
                                7'd121: resp_rdata <= rf_detectors[0];
                                7'd122: resp_rdata <= rf_detectors[1];
                                7'd123: resp_rdata <= rf_detectors[2];
                                7'd124: resp_rdata <= rf_detectors[3];
                                7'd125: resp_rdata <= temp_raw_reg;
                                default: resp_rdata <= '0;
                            endcase
                        end
                    end
                end

                RESP: begin
                    resp_valid <= 1'b1;
                end
            endcase
        end
    end

endmodule
