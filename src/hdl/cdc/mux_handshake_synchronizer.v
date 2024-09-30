

/*
    Module  : MUX_HANDSHAKE_SYNCHRONIZER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _MUX_HANDSHAKE_SYNCHRONIZER_V_
`define _MUX_HANDSHAKE_SYNCHRONIZER_V_

`include "src/hdl/cdc/synchronizer.v"

module mux_handshake_synchronizer #(
    parameter SYNC_STAGES = 2,
    parameter DATA_WIDTH  = 1
) (
    input wire i_in_clk, i_in_arst_n,
    input wire i_out_clk, i_out_arst_n,
    input wire i_in_wr, 
    output wire o_in_rdy,
    output wire o_in_ack,
    output wire o_out_valid,
    input wire[DATA_WIDTH-1:0] i_in_data, 
    output wire[DATA_WIDTH-1:0] o_out_data
);


    /////////////////////////////////////////////////////////////////////////////////////////////
    // INPUT CLOCK-DOMAIN

    reg[DATA_WIDTH-1:0] r_in_data;
    wire[DATA_WIDTH-1:0] ri_in_data;
    reg r_in_req, r_in_wr;
    wire ri_in_req, in_wr_flag;
    wire out_req_ack;

    synchronizer #(
        .STAGES     (SYNC_STAGES),
        .INIT       (1'b0)
    ) inst_sync_ack (
        .i_clk      (i_in_clk), 
        .i_arst_n   (i_in_arst_n),
        .i_async    (out_req_ack),
        .o_sync     ()
    );


    always@(posedge i_in_clk, negedge i_in_arst_n)
        if (~i_in_arst_n) begin
            r_in_data <= {DATA_WIDTH{1'b0}};
            r_in_wr   <= 1'b0;
            //
            r_in_req  <= 1'b0;
        end else begin
            r_in_data <= ri_in_data;
            r_in_wr   <= i_in_wr;
            //
            r_in_req  <= ri_in_req;
        end

    assign in_wr_flag = i_in_wr && ~r_in_wr; // P - Flag
    assign ri_in_req  = (in_wr_flag || r_in_req) && ~inst_sync_ack.o_sync; // SR
    assign ri_in_data = (in_wr_flag) ? i_in_data : r_in_data; 
    //
    assign o_in_rdy = ~r_in_req;
    assign o_in_ack = inst_sync_ack.o_sync;

    
    /////////////////////////////////////////////////////////////////////////////////////////////
    // OUTPUT CLOCK-DOMAIN

    reg r_out_req;
    wire ri_out_req;
    reg[DATA_WIDTH-1:0] r_out_data;
    wire[DATA_WIDTH-1:0] ri_out_data;

    synchronizer #(
        .STAGES     (SYNC_STAGES),
        .INIT       (1'b0)
    ) inst_sync_req (
        .i_clk      (i_out_clk), 
        .i_arst_n   (i_out_arst_n),
        .i_async    (r_in_req),
        .o_sync     ()
    );


    always @(posedge i_out_clk, negedge i_out_arst_n)
        if (~i_out_arst_n) begin 
            r_out_req  <= 1'b0;
            r_out_data <= {DATA_WIDTH{1'b0}};
        end else begin
            r_out_req  <= ri_out_req;
            r_out_data <= ri_out_data;
        end
                    
    assign ri_out_req  = inst_sync_req.o_sync;
    assign ri_out_data = (inst_sync_req.o_sync && ~r_out_req) ? r_in_data : r_out_data;
    assign out_req_ack = r_out_req; // synchronize back 
    // sync output
    assign o_out_data  = r_out_data;
    assign o_out_valid = r_out_req;

    wire sel;
    assign sel = (inst_sync_req.o_sync && ~r_out_req);

endmodule

`endif /* MUX_HANDSHAKE_SYNCHRONIZER */