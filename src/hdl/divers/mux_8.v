 /*
    Module  : MUX_8
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _MUX_8_V_
`define _MUX_8_V_

module mux_8 #(
    parameter DATA_WIDTH = 8
)(
    input wire[DATA_WIDTH-1:0] i_data_0,
    input wire[DATA_WIDTH-1:0] i_data_1,
    input wire[DATA_WIDTH-1:0] i_data_2,
    input wire[DATA_WIDTH-1:0] i_data_3,
    input wire[DATA_WIDTH-1:0] i_data_4,
    input wire[DATA_WIDTH-1:0] i_data_5,
    input wire[DATA_WIDTH-1:0] i_data_6,
    input wire[DATA_WIDTH-1:0] i_data_7, 
    input wire[2:0] i_sel,
    output reg [DATA_WIDTH-1:0] o_data
);

    // **************************************************
    // mux 8x1
    
    always@ * begin
        case(i_sel)
            3'b000: o_data = i_data_0;
            3'b001: o_data = i_data_1;
            3'b010: o_data = i_data_2;
            3'b011: o_data = i_data_3;
            3'b100: o_data = i_data_4;
            3'b101: o_data = i_data_5;
            3'b110: o_data = i_data_6;
            3'b111: o_data = i_data_7;
            default: o_data = 0;
        endcase
    end

endmodule

`endif /* MUX_8 */