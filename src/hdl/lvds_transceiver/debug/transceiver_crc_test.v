/*
    Module  : TRANSCEIVER_CRC_TEST
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _TRANSCEIVER_CRC_TEST_V_
`define _TRANSCEIVER_CRC_TEST_V_

`include "src/hdl/lvds_transceiver/include/lvds_transceiver_defines.vh"
//
`include "src/hdl/cdc/pulse_handshake_synchronizer.v"
`include "src/hdl/cdc/synchronizer.v"

module transceiver_crc_test (
    input wire i_sys_clk_120, i_sys_arst_n,
    input wire i_ctrl_mon_clk, i_ctrl_mon_arst_n,
    //
    input wire i_link_status_rply,
    //
    // CONTROL => MANIPULATE
    input wire i_ctrl_start_dllp, 
    input wire i_ctrl_start_tlp,
    //
    input wire i_ctrl_status_ack,
    output wire o_mon_status_rply,
    // DATA
    input wire[8:0] i_data,
    output wire[8:0] o_data
);


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    wire sync_start_dllp;
    wire sync_start_tlp;
    wire sync_status_ack;

    pulse_handshake_synchronizer #(
        .SYNC_STAGES   (2)
    ) inst_cdc_pulse_start_dllp (
        .i_in_clk       (i_ctrl_mon_clk),
        .i_in_arst_n    (i_ctrl_mon_arst_n),
        .i_out_clk      (i_sys_clk_120),
        .i_out_arst_n   (i_sys_arst_n),
        .i_in_pulse     (i_ctrl_start_dllp),
        .o_out_pulse    (sync_start_dllp)
    );


    pulse_handshake_synchronizer #(
        .SYNC_STAGES   (2)
    ) inst_cdc_pulse_start_tlp (
        .i_in_clk       (i_ctrl_mon_clk),
        .i_in_arst_n    (i_ctrl_mon_arst_n),
        .i_out_clk      (i_sys_clk_120),
        .i_out_arst_n   (i_sys_arst_n),
        .i_in_pulse     (i_ctrl_start_tlp),
        .o_out_pulse    (sync_start_tlp)
    );


    pulse_handshake_synchronizer #(
        .SYNC_STAGES   (2)
    ) inst_cdc_pulse_status_ack (
        .i_in_clk       (i_ctrl_mon_clk),
        .i_in_arst_n    (i_ctrl_mon_arst_n),
        .i_out_clk      (i_sys_clk_120),
        .i_out_arst_n   (i_sys_arst_n),
        .i_in_pulse     (i_ctrl_status_ack),
        .o_out_pulse    (sync_status_ack)
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    reg[8:0] r_data_i_a, r_data_i_b;
    reg[8:0] r_data_o;
    wire[8:0] ri_data_o;
    //
    reg r_enable_dllp, r_enable_tlp;
    wire ri_enable_dllp, ri_enable_tlp;
    //
    reg r_status_rply;
    wire ri_status_rply;

    always@ (posedge i_sys_clk_120, negedge i_sys_arst_n)
        if (~i_sys_arst_n) begin
            r_data_i_a    <= 9'b0;
            r_data_i_b    <= 9'b0;
            r_data_o      <= 9'b0;
            //
            r_enable_dllp <= 1'b0;
            r_enable_tlp  <= 1'b0;
            //
            r_status_rply <= 1'b0;
        end else begin
            r_data_i_a    <= i_data;
            r_data_i_b    <= r_data_i_a;
            r_data_o      <= ri_data_o;
            //
            r_enable_dllp <= ri_enable_dllp;
            r_enable_tlp  <= ri_enable_tlp;
            //
            r_status_rply <= ri_status_rply;
        end

    //
    assign dllp_start = ((r_data_i_b == {1'b1, `K_CODE_START_DLLP}) && (r_data_i_a[7])); // manipulate ack/nack - dllp
    assign tlp_start  = (r_data_i_a == {1'b1, `K_CODE_START_TLP});

    //
    assign ri_enable_dllp = (sync_start_dllp || r_enable_dllp) && ~dllp_start; // SR 
    assign ri_enable_tlp  = (sync_start_tlp || r_enable_tlp) && ~tlp_start; // SR
    //
    assign ri_status_rply = (i_link_status_rply || r_status_rply) && ~sync_status_ack;
    //
    assign ri_data_o = ((r_enable_dllp && dllp_start) || (r_enable_tlp && tlp_start)) ? i_data ^ 9'b000000001 : i_data; 
    //
    assign o_data = r_data_o;


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    synchronizer #(
        .STAGES     (2),
        .INIT       (1'b0)
    ) inst_cdc_status_rply (
        .i_clk      (i_ctrl_mon_clk),
        .i_arst_n   (i_ctrl_mon_arst_n),
        .i_async    (r_status_rply),
        .o_sync     (o_mon_status_rply)
    );



endmodule

`endif /* TRANSCEIVER_CRC_TEST */