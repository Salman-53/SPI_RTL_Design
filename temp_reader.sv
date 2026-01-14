`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/09/2025 07:34:52 PM
// Design Name: 
// Module Name: temp_reader
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


module temp_reader(
    input logic clk,
    input logic rst,
    input logic temp_mux_sel,
    input logic start_temp_conv,
    input logic adc_eoc,
    input logic [11:0] ADC_RESULT,
    output logic [15:0] temperature_c,
    output logic done
);

typedef enum logic [2:0] {
    IDLE, CONFIGURE, START_CONV, WAIT_EOC, READ_RESULT, CONVERT, DONE
} state_t;

state_t state;
logic [11:0] adc_value;
logic [7:0] ADC_CTRL;

// FSM logic
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state         <= IDLE;
        ADC_CTRL      <= 8'b0;
        temperature_c <= 16'd0;
        done          <= 0;
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
                ADC_CTRL[2:0] <= temp_mux_sel; // MUX_SEL for temp sensor
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
                // Convert ADC value to temperature in Celsius
                // Example: temperature_c = ((adc - 512) * 200) / 4095
                temperature_c <= ((adc_value - 12'd512) * 16'd200) / 12'd4095;
                state         <= DONE;
            end

            DONE: begin
                done <= 1;
                // Optionally return to IDLE for continuous operation
            end

        endcase
    end
end

endmodule

