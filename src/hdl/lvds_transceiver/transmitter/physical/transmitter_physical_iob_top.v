

/*
    Module  : TRANSMITTER_PHYSICAL_IOB_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _TRANSMITTER_PHYSICAL_IOB_TOP_V_
`define _TRANSMITTER_PHYSICAL_IOB_TOP_V_

`include "src/hdl/lvds_transceiver/transmitter/physical/xapp/encoder_8b10b.v"
`include "src/hdl/lvds_transceiver/transmitter/physical/physical_iob_oserdes.v"
//
`include "src/hdl/cdc/async_reset.v"



module transmitter_physical_iob_top #(
    parameter ENABLE_OSERDESE1 = 0
) (
    input wire i_clk_120, i_clk_120_arst_n,
    // clk_120
    input wire i_packet_k_en,
    input wire[7:0] i_packet_byte,
    //
    input wire i_clk_600,
    // clk_600
    output wire o_tx_p,
    output wire o_tx_n
);

//////////////////////////////////////////////////////////////////////////////////////////////
// LOCAL RESET
async_reset #(
    .STAGES   (2),
    .INIT     (1'b0),
    .RST_VAL  (1'b0)
) inst_local_reset_120 (
    .i_clk    (i_clk_120), 
    .i_rst_n  (i_clk_120_arst_n),
    .o_rst    ()
);


//////////////////////////////////////////////////////////////////////////////////////////////
// ENCODING

    encoder_8b10b #(        
        .C_HAS_DISP_IN     (0),
        .C_HAS_FORCE_CODE  (0),
        .C_FORCE_CODE_VAL  (0),
        .C_FORCE_CODE_DISP (0),
        .C_HAS_ND          (0),
        .C_HAS_KERR        (0)
    ) inst_8b10b_enc (
        .din               (i_packet_byte),
        .kin               (i_packet_k_en),
        .clk               (i_clk_120),
        .dout              (),
        .ce                (1'b1),
        .force_code        (1'b0),
        .force_disp        (1'b0),
        .disp_in           (1'b0),
        .disp_out          (),
        .kerr              (),
        .nd                ()
    );


////////////////////////////////////////////////////////////////////////////////////////////////
// SERIAL - OUT

    physical_iob_oserdes #(
        .ENABLE_OSERDESE1 (ENABLE_OSERDESE1)
    ) inst_oserdes (
        .i_clk_120        (i_clk_120),
        .i_clk_120_arst_n (inst_local_reset_120.o_rst),
        .i_clk_600        (i_clk_600),
        .i_data           (inst_8b10b_enc.dout),
        .o_tx_p           (o_tx_p),
        .o_tx_n           (o_tx_n)
    );

endmodule

`endif /* TRANSMITTER_PHYSICAL_IOB_TOP */