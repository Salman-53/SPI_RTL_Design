`timescale 1ns/1ps
module spi_master #(

    parameter ADDR_WIDTH = 14,          // 14 bit ADAR address
    parameter DATA_WIDTH = 8,          // 8 bit ADAR data
    parameter FRAME_BITS = 24         // fixed 24 bit frame size

)(

    input  logic                 clk,        // system clock
    input  logic                 rst_n,

    // command interface (from controller / data mgmt / sensor FSM)
    input  logic                   cmd_valid,       // pulse 1 cycle to start
    input  logic                   cmd_write,      // 1 = write, 0 = read
    input  logic  [ADDR_WIDTH-1:0] cmd_addr,      // addr input
    input  logic  [DATA_WIDTH-1:0] cmd_wdata,    // write data input
    output logic                   resp_valid,  // 1 cycle when resp_rdata valid
    output logic  [DATA_WIDTH-1:0] resp_rdata, // data from slave

    // SPI controller signals
    output logic                 sclk,          // clock signal
    output logic                 csb,          // active low chip select
    output logic                 mosi,        // SDIO from master
    input  logic                 miso,       // SDO from slave

    // configuration signals 
    input  logic [1:0]          spi_mode,     // 0--3 -> CPOL/CPHA
    input  integer              prescale     // number of clk cycles per half SCLK period
);

    // internal signals
    typedef enum logic [2:0] {IDLE, ASSERT_CS, SHIFT, DEASSERT_CS, RESP} state_t; // SPI master states 
    state_t state, next_state;

    logic [FRAME_BITS-1:0] shift_reg; // shift buffer for MOSI/MISO data
    integer bit_cnt;                 // count remaining bits in frame 
    integer sclk_cnt;               // prescaler count
    logic sclk_int;                // internal SCLK before apply CPOL
    logic sclk_en;                // enable for SCLK toggling
    logic sample_edge;           // edge to sample MISO on
    logic drive_edge;           // edge to drive MOSI on
    logic cpol, cpha;          // SPI mode signals

    // decode mode configuration
    always_comb begin

        cpol = (spi_mode[1]);           // bit1 = CPOL
        cpha = (spi_mode[0]);          // bit0 = CPHA

    // sample on (if CPHA==0) rising edge, else falling

    end

    // sclk generation (half-period counter)
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            sclk_cnt <= 0;        // prescaler count = 0
            sclk_int <= 1'b0;    // internal clock before CPOL = 0
            sclk_en  <= 1'b0;   // SCLK toggling enable = 0
 
        end else begin

            if (state == SHIFT) begin  // clock run only in shift state

                sclk_en <= 1'b1;      // SCLK toggling enabled

                if (sclk_cnt >= prescale-1) begin

                    sclk_cnt <= 0;           // prescaler count = 0
                    sclk_int <= ~sclk_int;  // toggling sclk_int -> generating SCLK waveform

                end else begin

                    sclk_cnt <= sclk_cnt + 1;

                end

            end else begin  // idle state behaviour 

                sclk_en  <= 1'b0;    // clock disabled
                sclk_cnt <= 0;      // counter cleared   
                sclk_int <= cpol ? 1'b1 : 1'b0; // idle level

            end

        end

    end

    // Compute actual sclk output considering CPOL
    always_comb begin

        sclk = sclk_int;

    end


   // frame: [23] = R/W, [22:9] = addr[13:0], [8:1] = data[7:0], [0]=pad(0)

    logic [ADDR_WIDTH-1:0] addr_reg;     // address buffer
    logic [DATA_WIDTH-1:0] data_reg;    // data buffer

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            shift_reg <= '0;     // fill all registers with zeros
            addr_reg <= '0;
            data_reg <= '0;

        end else begin

            if (state == ASSERT_CS && next_state == SHIFT) begin

                addr_reg <= cmd_addr;      // parallel address load
                data_reg <= cmd_wdata;    // parallel data load

                // building the frame to shift (MSB-first)
                shift_reg <= { cmd_write ? 1'b1 : 1'b0,
                               cmd_addr,
                               cmd_wdata,
                               1'b0 };

            end

        end

    end

    // FSM
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state <= IDLE;             //  returning to IDLE state 
            csb <= 1'b1;              // deasserting(csb=1) 
            mosi <= 1'b0;            // default MOSI low
            bit_cnt <= FRAME_BITS;  // resetting counters and response flags
            resp_valid <= 1'b0;
            resp_rdata <= '0;

        end else begin

            state <= next_state;
            resp_valid <= 1'b0;  // default low; asserted only in RESP

            case (state)

                IDLE: begin

                    csb <= 1'b1;     
                    mosi <= 1'b0;
                    bit_cnt <= FRAME_BITS;
                    // wait for cmd_valid to start transaction

                end

                ASSERT_CS: begin

                    csb <= 1'b0;    // selecting slave

            // If CPHA==0, first data bit must be valid before the first active SCLK edge

                    if (cpha == 0) begin

                        mosi <= shift_reg[FRAME_BITS-1]; // MSB of shift register

                    end

                end

                SHIFT: begin

                    if (sclk_en) begin  // clock enabled in shifting

       // tags the moment a toggle just happened, act exactly once per half-cycle

                        if (sclk_cnt == 0) begin

                          //  If cpol=0: active edge is rising (when sclk_int becomes 1)
                         //  If cpol=1: active edge is falling (when sclk_int becomes 0)

                            if (sclk_int == (cpol ^ 1)) begin // active edge selection

                                // CPHA = 0: Sample on active edge, Drive on trailing edge.
                               // CPHA = 1: Drive on active edge, Sample on trailing edge.

                                if (cpha == 0) begin

                                    // sampling MISO at this edge
                                   // shift in MISO at LSB side after shifting
                 

                                    shift_reg <= { shift_reg[FRAME_BITS-2:0], miso };
                                    bit_cnt <= bit_cnt - 1;

                        // preparing next MOSI bit for the next edge (driving on trailing edge)

                                    mosi <= (bit_cnt-1 > 0) ? shift_reg[FRAME_BITS-2] : 1'b0;

                                end else begin

                                // CPHA==1 -> drive on active edge, sample on trailing edge
                               // driving the current MSB on MOSI at the active edge

                                    mosi <= (bit_cnt > 0) ? shift_reg[FRAME_BITS-1] : 1'b0;

                                end

                            end else begin

                                // trailing edge operations 

                                if (cpha == 1) begin

                                    // now sample MISO

                                    shift_reg <= { shift_reg[FRAME_BITS-2:0], miso };
                                    bit_cnt <= bit_cnt - 1;

                                    // prepare next MOSI as well

                                    mosi <= (bit_cnt-1 > 0) ? shift_reg[FRAME_BITS-2] : 1'b0;

                                end else begin

                                    // CPHA==0 trailing edge: prepare MOSI for next active edge

                                    mosi <= (bit_cnt > 0) ? shift_reg[FRAME_BITS-1] : 1'b0;

                                end

                            end

                        end

                    end

                end

                DEASSERT_CS: begin

                    csb <= 1'b1;  // deasserting csb

                end

                RESP: begin

                    // preparing response: last 8 bits shifted in are the data (we placed slave output into LSBs)

                    resp_valid <= 1'b1;

                    resp_rdata <= shift_reg[DATA_WIDTH-1:0];  // LSB bits contain last-shifted data

                end

            endcase

        end

    end

    // next-state combinational
    always_comb begin

        next_state = state;

        case (state)

            IDLE: begin

                if (cmd_valid) begin

                   next_state = ASSERT_CS;
                
                end

            end

            ASSERT_CS: begin

                // allow one clk to settle CS and MOSI

                next_state = SHIFT;

            end

            SHIFT: begin

                if (bit_cnt <= 0) begin
                
                next_state = DEASSERT_CS;
 
                end

            end

            DEASSERT_CS: begin

                next_state = RESP;

            end

            RESP: begin

                next_state = IDLE;

            end

            default: next_state = IDLE;

        endcase

    end

endmodule
