 /*
    Module  : DEMUX_8
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _DEMUX_8_V_
`define _DEMUX_8_V_

module demux_8 #(
    parameter DATA_WIDTH = 8
)(
    input wire [DATA_WIDTH-1:0] i_data,
    input wire[2:0] i_sel,
    //
    output reg[DATA_WIDTH-1:0] o_data_0,
    output reg[DATA_WIDTH-1:0] o_data_1,
    output reg[DATA_WIDTH-1:0] o_data_2,
    output reg[DATA_WIDTH-1:0] o_data_3,
    output reg[DATA_WIDTH-1:0] o_data_4,
    output reg[DATA_WIDTH-1:0] o_data_5,
    output reg[DATA_WIDTH-1:0] o_data_6,
    output reg[DATA_WIDTH-1:0] o_data_7
);

    // **************************************************
    // demux 8x1
    
    always@ * begin
        // default
        o_data_0 = {DATA_WIDTH{1'b0}};
        o_data_1 = {DATA_WIDTH{1'b0}};
        o_data_2 = {DATA_WIDTH{1'b0}};
        o_data_3 = {DATA_WIDTH{1'b0}};
        o_data_4 = {DATA_WIDTH{1'b0}};
        o_data_5 = {DATA_WIDTH{1'b0}};
        o_data_6 = {DATA_WIDTH{1'b0}};
        o_data_7 = {DATA_WIDTH{1'b0}};
        //

        case(i_sel)
            3'b000: o_data_0 = i_data;
            3'b001: o_data_1 = i_data;
            3'b010: o_data_2 = i_data;
            3'b011: o_data_3 = i_data;
            3'b100: o_data_4 = i_data;
            3'b101: o_data_5 = i_data;
            3'b110: o_data_6 = i_data;
            3'b111: o_data_7 = i_data;
        endcase
    end

endmodule

`endif /* DEMUX_8 */