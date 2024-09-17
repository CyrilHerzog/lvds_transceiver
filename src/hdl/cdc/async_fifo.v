
/*
    Module  : ASYNC_FIFO
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _ASYNC_FIFO_V_
`define _ASYNC_FIFO_V_


module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3,
    parameter AFULL_LIM  = 6,
    parameter AEMPTY_LIM = 1
)(
    input wire i_wr_clk, i_wr_arst_n,
    input wire i_rd_clk, i_rd_arst_n,
    input wire i_wr, i_rd,
    input wire [DATA_WIDTH-1:0] i_data,
    output wire [DATA_WIDTH-1:0] o_data,
    output wire o_almost_full, o_almost_empty,
    output wire o_full, o_empty
);
 

    reg [DATA_WIDTH-1:0] r_ram [(2**ADDR_WIDTH)-1:0];

    reg [ADDR_WIDTH:0] r_wr_ptr_bin, r_rd_ptr_bin;    
    wire [ADDR_WIDTH:0] ri_wr_ptr_bin, ri_rd_ptr_bin;

    reg [ADDR_WIDTH:0] r_wr_ptr_gray, r_rd_ptr_gray;    
    wire [ADDR_WIDTH:0] ri_wr_ptr_gray, ri_rd_ptr_gray;

    wire[ADDR_WIDTH:0] wr_ptr_gray, rd_ptr_gray;
    wire[ADDR_WIDTH:0] wr_ptr_bin_sync, rd_ptr_bin_sync;


    (* ASYNC_REG = "TRUE", shreg_extract = "no" *)
    reg[ADDR_WIDTH:0] r_wr_ptr_gray_meta;
    (* ASYNC_REG = "TRUE", shreg_extract = "no" *)
    reg[ADDR_WIDTH:0] r_wr_ptr_gray_sync;
    (* ASYNC_REG = "TRUE", shreg_extract = "no" *)
    reg[ADDR_WIDTH:0] r_rd_ptr_gray_meta;
    (* ASYNC_REG = "TRUE", shreg_extract = "no" *)
    reg[ADDR_WIDTH:0] r_rd_ptr_gray_sync;

    wire[ADDR_WIDTH:0] ri_wr_ptr_gray_meta, ri_wr_ptr_gray_sync;
    wire[ADDR_WIDTH:0] ri_rd_ptr_gray_meta, ri_rd_ptr_gray_sync;

    wire[ADDR_WIDTH:0] ri_wr_ptr_diff, ri_rd_ptr_diff;
    reg[ADDR_WIDTH:0] r_wr_ptr_diff, r_rd_ptr_diff;

    reg r_empty = 1'b1;
    reg r_full  = 1'b0;
    wire ri_empty, ri_full;

    reg r_almost_empty = 1'b1;
    reg r_almost_full;
    wire ri_almost_empty;
    wire ri_almost_full;


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // WRITE DOMAINE

    always@(posedge i_wr_clk, negedge i_wr_arst_n)
        if (~i_wr_arst_n) begin
            // two-ff synchronizer
            r_rd_ptr_gray_meta <= 0;
            r_rd_ptr_gray_sync <= 0;
            // write-pointer logic
            r_wr_ptr_bin  <= 0;
            r_wr_ptr_gray <= 0;
            r_wr_ptr_diff <= 0;
            r_full        <= 1'b0;
            r_almost_full <= 1'b0;
        end else begin
            // two-ff synchronizer
            r_rd_ptr_gray_meta <= ri_rd_ptr_gray_meta;
            r_rd_ptr_gray_sync <= ri_rd_ptr_gray_sync;
            // write-pointer logic
            r_wr_ptr_bin  <= ri_wr_ptr_bin;
            r_wr_ptr_gray <= ri_wr_ptr_gray;
            r_wr_ptr_diff <= ri_wr_ptr_diff;
            r_full        <= ri_full;
            r_almost_full <= ri_almost_full;
        end


    assign ri_rd_ptr_gray_meta = r_rd_ptr_gray;
    assign ri_rd_ptr_gray_sync = r_rd_ptr_gray_meta;

    // USE LUT - Primitive
    // assign ri_wr_ptr_bin = (i_wr & ~r_full) ? r_wr_ptr_bin + 1 : r_wr_ptr_bin;

    // USE CARRY - Primitive
    assign ri_wr_ptr_bin = r_wr_ptr_bin + {{ADDR_WIDTH{1'b0}}, (i_wr & ~r_full)}; 

    // generate full 
    assign ri_full = (ri_wr_ptr_gray == {~r_rd_ptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1], r_rd_ptr_gray_sync[ADDR_WIDTH-2:0]});
    assign o_full = r_full;

    // generate almost full => for higher frequency it may be necessary to use more stage-registers
    assign ri_wr_ptr_diff = (ri_wr_ptr_bin > rd_ptr_bin_sync) ? (ri_wr_ptr_bin - rd_ptr_bin_sync) : ((ri_wr_ptr_bin - rd_ptr_bin_sync) + (1 << (ADDR_WIDTH + 1)));
    assign ri_almost_full = (r_wr_ptr_diff >= AFULL_LIM);
    assign o_almost_full  = r_almost_full;

     

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // READ DOMAINE

    always@(posedge i_rd_clk, negedge i_rd_arst_n)
        if (~i_rd_arst_n) begin
            // two-ff synchronizer
            r_wr_ptr_gray_meta <= 0;
            r_wr_ptr_gray_sync <= 0;
            // read-pointer logic
            r_rd_ptr_bin   <= 0;
            r_rd_ptr_gray  <= 0;
            r_rd_ptr_diff  <= 0;
            r_empty        <= 1'b1;
            r_almost_empty <= 1'b1;
        end else begin
            // two-ff synchronizer
            r_wr_ptr_gray_meta <= ri_wr_ptr_gray_meta;
            r_wr_ptr_gray_sync <= ri_wr_ptr_gray_sync;
            // read-pointer logic
            r_rd_ptr_bin   <= ri_rd_ptr_bin;
            r_rd_ptr_gray  <= ri_rd_ptr_gray;
            r_rd_ptr_diff  <= ri_rd_ptr_diff;
            r_empty        <= ri_empty;
            r_almost_empty <= ri_almost_empty;
        end

    assign ri_wr_ptr_gray_meta = r_wr_ptr_gray;
    assign ri_wr_ptr_gray_sync = r_wr_ptr_gray_meta;

    // address incrementer
    assign ri_rd_ptr_bin = (i_rd && ~r_empty) ? r_rd_ptr_bin + 1 : r_rd_ptr_bin;
    assign ri_empty = (ri_rd_ptr_gray == r_wr_ptr_gray_sync);
    assign o_empty = r_empty;

    // almost empty
    assign ri_rd_ptr_diff  = (ri_rd_ptr_bin > wr_ptr_bin_sync) ? ((wr_ptr_bin_sync - ri_rd_ptr_bin)  + (1 << (ADDR_WIDTH + 1))): (wr_ptr_bin_sync - ri_rd_ptr_bin);
    assign ri_almost_empty = (r_rd_ptr_diff <= AEMPTY_LIM);
    assign o_almost_empty  = r_almost_empty;

    // bram
    integer i;
    initial begin
        // clear register-file
        for (i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
            r_ram[i] = 0;
        end
    end

    always@(posedge i_wr_clk)
        if (i_wr && ~r_full)
            r_ram[r_wr_ptr_bin[ADDR_WIDTH-1:0]] <= i_data;

    // synchronous read
    assign o_data = r_ram[r_rd_ptr_bin[ADDR_WIDTH-1:0]];

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CONVERT

    // bin to gray    
    // assign ri_wr_ptr_gray = {1'b0, ri_wr_ptr_bin[ADDR_WIDTH:1]} ^ ri_wr_ptr_bin;
    // assign ri_rd_ptr_gray = {1'b0, ri_rd_ptr_bin[ADDR_WIDTH:1]} ^ ri_rd_ptr_bin;

    assign ri_wr_ptr_gray = (ri_wr_ptr_bin >> 1) ^ ri_wr_ptr_bin;
    assign ri_rd_ptr_gray = (ri_rd_ptr_bin >> 1) ^ ri_rd_ptr_bin;

    // gray to bin
    genvar j;
    generate
        for (j = 0; j <= ADDR_WIDTH; j = j + 1) begin 
            assign wr_ptr_bin_sync[j] = ^(r_wr_ptr_gray_sync >> j);
            assign rd_ptr_bin_sync[j] = ^(r_rd_ptr_gray_sync >> j);
        end
    endgenerate

  

endmodule

`endif /* ASYNC_FIFO */