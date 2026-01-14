`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/09/2025 08:51:29 PM
// Design Name: 
// Module Name: tb_top_module
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


module tb_top_module;

    // Inputs
    logic clk, rst;
    logic start_rf_conv, start_temp_conv;
    logic [2:0] detector_sel;
    logic [11:0] ADC_RESULT;
    logic adc_eoc;
    logic select_data_source;

    // Outputs
    logic [7:0] output_data;
    logic done_rf, done_temp;

    // Instantiate DUT
    top_module dut (
        .clk(clk),
        .rst(rst),
        .start_rf_conv(start_rf_conv),
        .start_temp_conv(start_temp_conv),
        .detector_sel(detector_sel),
        .ADC_RESULT(ADC_RESULT),
        .adc_eoc(adc_eoc),
        .select_data_source(select_data_source),
        .output_data(output_data),
        .done_rf(done_rf),
        .done_temp(done_temp)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        start_rf_conv = 0;
        start_temp_conv = 0;
        detector_sel = 3'b001;
        ADC_RESULT = 12'h000;
        adc_eoc = 0;
        select_data_source = 0;

        #10 rst = 0;

        // Test RF reading
        #10 start_rf_conv = 1;
        #10 start_rf_conv = 0;

        // Wait for RF done
        wait(done_rf);
        $display("RF Reading: %0d dBm", output_data);

        // Switch to temperature
        select_data_source = 1;
        ADC_RESULT = 12'h3A0; // Dummy ADC value
        adc_eoc = 1;

        #10 start_temp_conv = 1;
        #10 start_temp_conv = 0;

        // Wait for Temp done
        wait(done_temp);
        $display("Temperature Reading: %0d °C", output_data);

        #20 $finish;
    end

endmodule

