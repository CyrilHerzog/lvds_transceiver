

/*
    Module  : TRANSCEIVER_LINK_LAYER_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _TRANSCEIVER_LINK_LAYER_TOP_V_
`define _TRANSCEIVER_LINK_LAYER_TOP_V_



`include "src/hdl/lvds_transceiver/include/lvds_transceiver_defines.vh"
//
`include "src/hdl/lvds_transceiver/receiver/receiver_packet_interface_top.v"
`include "src/hdl/lvds_transceiver/transmitter/transmitter_packet_interface_top.v"

//
`include "src/hdl/lvds_transceiver/transceiver_link_controller.v"


module transceiver_link_layer_top #(
    parameter TLP_TX_WIDTH          = `DEFAULT_TLP_WIDTH,
    parameter TLP_RX_WIDTH          = `DEFAULT_TLP_WIDTH,
    parameter TLP_ID_WIDTH          = `CONFIG_TLP_ID_WIDTH,
    parameter TLP_BUFFER_TYPE       = `DEFAULT_TLP_BUFFER_TYPE,
    parameter TLP_BUFFER_ADDR_WIDTH = `DEFAULT_TLP_BUFFER_ADDR_WIDTH,
    parameter CRC_INIT              = `DEFAULT_CRC_INIT,
    parameter CRC_POLY              = `DEFAULT_CRC_POLY
)(
    input wire i_sys_clk_120, i_sys_arst_n,
    // Transaction - Layer
    input wire i_tlp_wr_clk, i_tlp_rd_clk,
    input wire i_tlp_wr, i_tlp_rd,
    input wire [TLP_TX_WIDTH-1:0] i_tlp,
    output wire [TLP_RX_WIDTH-1:0] o_tlp,
    output wire o_tlp_rdy, o_tlp_valid,
    //
    // Physical - Layer
    input wire i_phys_cal_done, i_phys_cal_fail,
    output wire o_phys_cal_start,
    //
    input wire i_phys_packet_k_en,
    input wire[7:0] i_phys_packet_byte,
    output wire o_phys_packet_k_en,
    output wire[7:0] o_phys_packet_byte,
    //
    // status bits
    output wire o_status_connect,
    //
    // link - state (only for testing)
    output wire o_tx_state_rply
);


/////////////////////////////////////////////////////////////////////////////////////////////////////////
// LINK - CONTROLLER

transceiver_link_controller #(
    .TLP_ID_WIDTH           (TLP_ID_WIDTH)
) inst_transceiver_link_controller (
    .i_clk                  (i_sys_clk_120), 
    .i_arst_n               (i_sys_arst_n),
    // TRANSMITTER
    .i_tx_dllp_rdy          (inst_transmitter_packet_interface_top.o_dllp_rdy),
    .o_tx_dllp              (),
    .o_tx_dllp_wr           (),
    //
    .o_tx_start             (),
    .o_tx_stop              (),
    .o_tx_rply              (),
    //
    .i_tx_ack_req           (~inst_transmitter_packet_interface_top.o_tlp_id_all_ack), //  
    .i_tx_ack_id            (inst_transmitter_packet_interface_top.o_tlp_id_ack),
    .o_tx_id_ack            (),
    //
    // RECEIVER
    .i_rx_dllp_valid        (inst_receiver_packet_interface_top.o_dllp_valid),
    .i_rx_dllp              (inst_receiver_packet_interface_top.o_dllp),
    .o_rx_dllp_rd           (),
    //
    .i_rx_tlp_rdy           (inst_receiver_packet_interface_top.o_tlp_rdy),
    .i_rx_id_result_valid   (inst_receiver_packet_interface_top.o_status_id_valid),
    .i_rx_id_result         (inst_receiver_packet_interface_top.o_status_id),
    .o_rx_id_result_rd      (),
    //
    // PHYSICAL
    .i_phys_cal_done        (i_phys_cal_done),
    .i_phys_cal_fail        (i_phys_cal_fail),
    .o_phys_cal_start       (o_phys_cal_start),
    //
    // STATUS
    .o_status_connect       (o_status_connect)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TRANSMITTER

transmitter_packet_interface_top #(
    .TLP_WIDTH              (TLP_TX_WIDTH),
    .TLP_ID_WIDTH           (TLP_ID_WIDTH),
    .TLP_BUFFER_TYPE        (TLP_BUFFER_TYPE),
    .TLP_BUFFER_ADDR_WIDTH  (TLP_BUFFER_ADDR_WIDTH),       
    .DLLP_WIDTH             (`CONFIG_DLLP_WIDTH),
    .DLLP_BUFFER_ADDR_WIDTH (`CONFIG_DLLP_BUFFER_ADDR_WIDTH),
    .CRC_INIT               (CRC_INIT),
    .CRC_POLY               (CRC_POLY)
) inst_transmitter_packet_interface_top (
    .i_sys_clk_120          (i_sys_clk_120),
    .i_sys_arst_n           (i_sys_arst_n),
    // TLP - INTERFACE
    .i_tlp_wr_clk           (i_tlp_wr_clk),
    .i_tlp_wr               (i_tlp_wr),
    .i_tlp                  (i_tlp),
    .o_tlp_rdy              (o_tlp_rdy),
    // LINK - MANAGER
    .i_dllp_wr              (inst_transceiver_link_controller.o_tx_dllp_wr),
    .i_dllp                 (inst_transceiver_link_controller.o_tx_dllp),
    .o_dllp_rdy             (),
    //
    .i_tlp_start            (inst_transceiver_link_controller.o_tx_start),
    .i_tlp_stop             (inst_transceiver_link_controller.o_tx_stop),
    .i_tlp_rply_start       (inst_transceiver_link_controller.o_tx_rply),
    .i_tlp_id_ack           (inst_transceiver_link_controller.o_tx_id_ack),
    .o_tlp_rply_act         (o_tx_state_rply), // replay is active
    .o_tlp_id_all_ack       (), // standby => no jobs
    .o_tlp_id_wait_ack      (), // transmittion stopped => wait for acknowledge
    .o_tlp_id_nack          (), // not accepted id's => msg in transmission
    .o_tlp_id_ack           (), // accepted id
    //
    .o_phys_packet_k_en     (o_phys_packet_k_en),
    .o_phys_packet_byte     (o_phys_packet_byte)
);

////////////////////////////////////////////////////////////////////////////////////////////////////
// RECEIVER

receiver_packet_interface_top #(
    .TLP_WIDTH              (TLP_RX_WIDTH),
    .TLP_ID_WIDTH           (TLP_ID_WIDTH),
    .TLP_BUFFER_TYPE        (TLP_BUFFER_TYPE),
    .TLP_BUFFER_ADDR_WIDTH  (TLP_BUFFER_ADDR_WIDTH),       
    .DLLP_WIDTH             (`CONFIG_DLLP_WIDTH),
    .DLLP_BUFFER_ADDR_WIDTH (`CONFIG_DLLP_BUFFER_ADDR_WIDTH),
    .CRC_INIT               (CRC_INIT),
    .CRC_POLY               (CRC_POLY)
) inst_receiver_packet_interface_top (
    .i_sys_clk_120          (i_sys_clk_120), 
    .i_sys_arst_n           (i_sys_arst_n),
    // TLP - INTERFACE 
    .i_tlp_rd_clk           (i_tlp_rd_clk),
    .i_tlp_rd               (i_tlp_rd),
    .o_tlp                  (o_tlp),
    .o_tlp_valid            (o_tlp_valid),
    .o_tlp_rdy              (),
    // LINK - MANAGER
    .i_dllp_rd              (inst_transceiver_link_controller.o_rx_dllp_rd),
    .o_dllp                 (),
    .o_dllp_valid           (),
    //
    .i_status_id_rd         (inst_transceiver_link_controller.o_rx_id_result_rd),
    .o_status_id            (),
    .o_status_id_valid      (),
    //
    .i_phys_packet_k_en     (i_phys_packet_k_en),
    .i_phys_packet_byte     (i_phys_packet_byte)
);


endmodule

`endif /* TRANSCEIVER_LINK_LAYER_TOP */