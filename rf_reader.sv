`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/09/2025 07:34:31 PM
// Design Name: 
// Module Name: rf_reader
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
//////////////////////////////////////////////////////////////////////////////////


module rf_reader(
    input logic clk,
    input logic rst,
    input logic [2:0] detector_sel,  // 001 to 100 for DET1 to DET4
    output logic [7:0] power_dbm,
    output logic done
    );
    logic [7:0] adc_value;
    logic adc_eoc;
    logic start_conv;

    // Simulated ADC control register
    logic [7:0] ADC_CTRL;
    logic [7:0] ADC_RESULT;
    
    typedef enum logic [2:0] {
          IDLE, CONFIGURE, START_CONV, WAIT_EOC, READ_RESULT, CONVERT, DONE
        } state_t;
        state_t state;
        // FSM logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            ADC_CTRL   <= 8'b0;
            power_dbm  <= 8'b0;
            done       <= 0;
        end else begin
            case (state)

                IDLE: begin
                    done     <= 0;
                    ADC_CTRL <= 8'b0;
                    state    <= CONFIGURE;
                end

                CONFIGURE: begin
                    ADC_CTRL[7]   <= 1;           // ADC_EN
                    ADC_CTRL[6]   <= 1;           // CLK_EN
                    ADC_CTRL[2:0] <= detector_sel; // MUX_SEL
                    state         <= START_CONV;
                end

                START_CONV: begin
                    ADC_CTRL[5] <= 1; // ST_CONV
                    state       <= WAIT_EOC;
                end

                WAIT_EOC: begin
                    if (adc_eoc == 1)
                        state <= READ_RESULT;
                end

                READ_RESULT: begin
                    adc_value <= ADC_RESULT;
                    state     <= CONVERT;
                end

                CONVERT: begin
                    power_dbm <= (adc_value - 8'd128) >> 2; // (adc - 128)/4
                    state     <= DONE;
                end

                DONE: begin
                    done <= 1;
                    // Optionally go back to IDLE if you want continuous reading
                end

            endcase
        end
    end    

endmodule
