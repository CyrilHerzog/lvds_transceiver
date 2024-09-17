
/*
    Module  : TRANSCEIVER_ELASTIC_BUFFER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _TRANSCEIVER_ELASTIC_BUFFER_V_
`define _TRANSCEIVER_ELASTIC_BUFFER_V_

`include "src/hdl/cdc/async_fifo.v"
`include "src/hdl/cdc/async_reset.v"

module transceiver_elastic_buffer #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3
)(
    input wire i_wr_clk, i_wr_arst_n,
    input wire i_rd_clk, i_rd_arst_n,
    input wire [DATA_WIDTH-1:0] i_data,
    output wire [DATA_WIDTH-1:0] o_data
);

    localparam SKP_SYMBOL = {1'b1, 8'h7c};
 
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // RESET
    wire local_wr_arst_n;
    wire local_rd_arst_n;

    async_reset #(
        .STAGES   (2),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_reset_wr (
        .i_clk    (i_wr_clk), 
        .i_rst_n  (i_wr_arst_n),
        .o_rst    (local_wr_arst_n)
    );

    async_reset #(
        .STAGES   (2),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_reset_rd (
        .i_clk    (i_rd_clk), 
        .i_rst_n  (i_rd_arst_n),
        .o_rst    (local_rd_arst_n)
    );

    

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // WRITE - ENABLE

    reg[DATA_WIDTH-1:0] r_data_i;
    wire[DATA_WIDTH-1:0] ri_data_i;
    reg r_wr_enable;
    wire ri_wr_enable;

    always@(posedge i_wr_clk, negedge local_wr_arst_n)
        if (~local_wr_arst_n) begin
            r_data_i    <= SKP_SYMBOL;
            r_wr_enable <= 1'b0;
        end else begin
            r_data_i    <= ri_data_i;
            r_wr_enable <= ri_wr_enable;
        end

    assign ri_data_i    = i_data;
    assign ri_wr_enable = ~(inst_async_fifo.o_almost_full && (i_data == SKP_SYMBOL));


    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // READ - ENABLE

    reg[DATA_WIDTH-1:0] r_data_o;
    wire[DATA_WIDTH-1:0] ri_data_o;
    reg r_rd_enable;
    wire ri_rd_enable;

    always@(posedge i_rd_clk, negedge local_rd_arst_n)
        if (~local_rd_arst_n) begin
            r_data_o    <= SKP_SYMBOL;
            r_rd_enable <= 1'b0;
        end else begin
            r_data_o    <= ri_data_o;
            r_rd_enable <= ri_rd_enable;
        end

    assign ri_rd_enable = ~(inst_async_fifo.o_almost_empty && (inst_async_fifo.o_data == SKP_SYMBOL));
    assign ri_data_o    = inst_async_fifo.o_data;
    //
    assign o_data = r_data_o;

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // ASYNC - FIFO

    async_fifo #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .AFULL_LIM      ((1 << (ADDR_WIDTH-1)) + 4),
        .AEMPTY_LIM     ((1 << (ADDR_WIDTH-1)) - 4)
    ) inst_async_fifo (
        .i_wr_clk       (i_wr_clk), 
        .i_wr_arst_n    (local_wr_arst_n),
        .i_rd_clk       (i_rd_clk),
        .i_rd_arst_n    (local_rd_arst_n),
        .i_wr           (r_wr_enable),
        .i_rd           (r_rd_enable),
        .i_data         (r_data_i),
        .o_data         (),
        .o_almost_full  (),
        .o_almost_empty (),
        .o_full         (),
        .o_empty        ()
    );

    


endmodule

`endif /* TRANSCEIVER_ELASTIC_BUFFER */