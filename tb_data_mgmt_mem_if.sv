`timescale 1ns/1ps

module tb_data_mgmt_mem_if;

    // Parameters
    localparam ADDR_WIDTH = 7;
    localparam DATA_WIDTH = 24;

    // DUT signals
    logic                     clk;
    logic                     rst_n;
    logic                     cmd_valid;
    logic                     cmd_write;
    logic [ADDR_WIDTH-1:0]    cmd_addr;
    logic [DATA_WIDTH-1:0]    cmd_wdata;
    logic                     resp_valid;
    logic [DATA_WIDTH-1:0]    resp_rdata;
    logic                     det_update_valid;
    logic [1:0]               det_index;
    logic [DATA_WIDTH-1:0]    det_value;
    logic                     temp_update_valid;
    logic [DATA_WIDTH-1:0]    temp_raw_value;
    logic                     mem_busy;

    // Clock generation: 10ns period
    always #5 clk = ~clk;

    // DUT instantiation
    data_mgmt_mem_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_valid(cmd_valid),
        .cmd_write(cmd_write),
        .cmd_addr(cmd_addr),
        .cmd_wdata(cmd_wdata),
        .resp_valid(resp_valid),
        .resp_rdata(resp_rdata),
        .det_update_valid(det_update_valid),
        .det_index(det_index),
        .det_value(det_value),
        .temp_update_valid(temp_update_valid),
        .temp_raw_value(temp_raw_value),
        .mem_busy(mem_busy)
    );

    // Simple task for write command
    task automatic write_cmd(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        @(posedge clk);
        cmd_valid <= 1;
        cmd_write <= 1;
        cmd_addr  <= addr;
        cmd_wdata <= data;
        @(posedge clk);
        cmd_valid <= 0;
        cmd_write <= 0;
        cmd_addr  <= 0;
        cmd_wdata <= 0;
        wait(resp_valid);
        $display("[%0t] WRITE: addr=%0d, data=0x%h", $time, addr, resp_rdata);
    endtask

    // Simple task for read command
    task automatic read_cmd(input [ADDR_WIDTH-1:0] addr);
        @(posedge clk);
        cmd_valid <= 1;
        cmd_write <= 0;
        cmd_addr  <= addr;
        cmd_wdata <= '0;
        @(posedge clk);
        cmd_valid <= 0;
        cmd_addr  <= 0;
        wait(resp_valid);
        $display("[%0t] READ: addr=%0d, data=0x%h", $time, addr, resp_rdata);
    endtask

    initial begin
        // VCD dump
        $dumpfile("tb_data_mgmt_mem_if.vcd");
        $dumpvars(0, tb_data_mgmt_mem_if);

        // Init
        clk = 0;
        rst_n = 0;
        cmd_valid = 0;
        cmd_write = 0;
        cmd_addr = 0;
        cmd_wdata = 0;
        det_update_valid = 0;
        det_index = 0;
        det_value = 0;
        temp_update_valid = 0;
        temp_raw_value = 0;

        // Reset
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Write to beam memory
        write_cmd(7'd5, 24'hABCDEF);
        write_cmd(7'd10, 24'h123456);

        // Read back from beam memory
        read_cmd(7'd5);
        read_cmd(7'd10);

        // Write to RF detectors via command interface
        write_cmd(7'd121, 24'h000111);
        write_cmd(7'd122, 24'h000222);

        // Read back RF detectors
        read_cmd(7'd121);
        read_cmd(7'd122);

        // Write to temperature register
        write_cmd(7'd125, 24'hFACE01);
        read_cmd(7'd125);

        // External detector update (detector #2)
        @(posedge clk);
        det_update_valid <= 1;
        det_index <= 2;
        det_value <= 24'hABC123;
        @(posedge clk);
        det_update_valid <= 0;

        // External temperature update
        @(posedge clk);
        temp_update_valid <= 1;
        temp_raw_value <= 24'hDEADBE;
        @(posedge clk);
        temp_update_valid <= 0;

        // Read updated detector/temp
        read_cmd(7'd123);
        read_cmd(7'd125);

        // Finish simulation
        repeat (5) @(posedge clk);
        $finish;
    end

endmodule
