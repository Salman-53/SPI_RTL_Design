`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/09/2025 07:54:54 PM
// Design Name: 
// Module Name: tb_rf_reader
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


module tb_rf_reader;

    // Testbench signals
    logic clk;
    logic rst;
    logic [2:0] detector_sel;
    logic [7:0] power_dbm;
    logic done;

    // Internal simulation signals
    logic [7:0] ADC_RESULT;
    logic       adc_eoc;

    // Instantiate DUT (Device Under Test)
    rf_reader dut (
        .clk(clk),
        .rst(rst),
        .detector_sel(detector_sel),
        .power_dbm(power_dbm),
        .done(done)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Stimulus
    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        detector_sel = 3'b001; // Select DET1
        ADC_RESULT = 8'd0;
        adc_eoc = 0;

        // Reset pulse
        #10 rst = 0;

        // Wait for FSM to reach WAIT_EOC
        #50;

        // Simulate ADC conversion complete
        ADC_RESULT = 8'd180; // Simulated ADC value
        adc_eoc = 1;

        // Wait for FSM to process result
        #20;

        // Display result
        $display("Power in dBm: %d", power_dbm);
        $display("Done signal: %b", done);

        // Finish simulation
        #20 $finish;
    end

endmodule
