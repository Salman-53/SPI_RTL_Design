`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/09/2025 08:49:59 PM
// Design Name: 
// Module Name: top_module
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


module top_module(
    input clk, rst,
    input start_rf_conv, start_temp_conv,
    input [2:0] detector_sel,
    input [11:0] ADC_RESULT,
    input adc_eoc,
    input select_data_source, // 0 = RF, 1 = Temp
    output [7:0] output_data,
    output done_rf, done_temp
);

    wire [7:0] power_dbm;
    wire [15:0] temperature_c;

    rf_reader rf_reader (
        .clk(clk),
        .rst(rst),
        .detector_sel(detector_sel),
        .power_dbm(power_dbm),
        .done(done_rf)
    );

    temp_reader temp_reader (
        .clk(clk),
        .rst(rst),
        .start_temp_conv(start_temp_conv),
        .adc_eoc(adc_eoc),
        .ADC_RESULT(ADC_RESULT),
        .temperature_c(temperature_c),
        .done(done_temp)
    );

    // 2x1 MUX
    assign output_data = (select_data_source == 0) ? power_dbm : temperature_c[7:0];

endmodule
