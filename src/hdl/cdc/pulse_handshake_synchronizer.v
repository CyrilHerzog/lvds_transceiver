/*
    Module  : PULSE_HANDSHAKE_SYNCHRONIZER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _PULSE_HANDSHAKE_SYNCHRONIZER_V_
`define _PULSE_HANDSHAKE_SYNCHRONIZER_V_

`include "src/hdl/cdc/synchronizer.v"

module pulse_handshake_synchronizer #(
    parameter SYNC_STAGES = 2
) (
    input wire i_in_clk, i_in_arst_n,
    input wire i_out_clk, i_out_arst_n,
    input wire i_in_pulse, 
    output wire o_out_pulse
);


    /////////////////////////////////////////////////////////////////////////////////////////////
    // INPUT CLOCK-DOMAIN

    reg r_in_req;
    wire ri_in_req;
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
        if (~i_in_arst_n)
            r_in_req  <= 1'b0;
        else 
            r_in_req  <= ri_in_req;


    assign ri_in_req  = (i_in_pulse || r_in_req) && ~inst_sync_ack.o_sync; // SR

    
    /////////////////////////////////////////////////////////////////////////////////////////////
    // OUTPUT CLOCK-DOMAIN

    reg r_out_req;
    wire ri_out_req;

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
        if (~i_out_arst_n) 
            r_out_req  <= 1'b0;
        else
            r_out_req  <= ri_out_req;
                    
    assign ri_out_req  = inst_sync_req.o_sync;
    assign out_req_ack = r_out_req; // synchronize back 
    assign o_out_pulse = (inst_sync_req.o_sync && ~r_out_req);

endmodule

`endif /* PULSE_HANDSHAKE_SYNCHRONIZER */