`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/09/2025 08:22:32 PM
// Design Name: 
// Module Name: tb_temp_reader
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


module tb_temp_reader;

    // Testbench signals
    logic clk;
    logic rst;
    logic temp_mux_sel;
    logic start_temp_conv;
    logic adc_eoc;
    logic [11:0] ADC_RESULT;
    logic [15:0] temperature_c;
    logic done;

    // Instantiate the DUT (Device Under Test)
    temp_reader uut (
        .clk(clk),
        .rst(rst),
        .temp_mux_sel(temp_mux_sel),
        .start_temp_conv(start_temp_conv),
        .adc_eoc(adc_eoc),
        .ADC_RESULT(ADC_RESULT),
        .temperature_c(temperature_c),
        .done(done)
    );

    // Clock generation: 10 ns period
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        temp_mux_sel = 3'b001; // Example MUX channel
        start_temp_conv = 0;
        adc_eoc = 0;
        ADC_RESULT = 12'd0;

        // Apply reset
        #12;
        rst = 0;

        // Start temperature conversion
        #10;
        start_temp_conv = 1;
        #10;
        start_temp_conv = 0;

        // Wait for FSM to reach WAIT_EOC
        #50;

        // Simulate ADC end-of-conversion
        adc_eoc = 1;
        ADC_RESULT = 12'd1024; // Example ADC value

        #10;
        adc_eoc = 0;

        // Wait for conversion and DONE signal
        #30;

        // Display result
        $display("Temperature (°C): %0d", temperature_c);
        $display("Done signal: %b", done);

        // Finish simulation
        #20;
        $finish;
    end

endmodule
