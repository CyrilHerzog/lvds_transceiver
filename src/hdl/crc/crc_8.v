
 /*
    Module  : CRC_8
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/

`ifndef _CRC_8_V_
`define _CRC_8_V_

module crc_8 #(
    parameter POLY  = 8'b00000111, // polynominal x^8 + x^2 + x^1 + 1 
    parameter INIT  = 8'b11111111  // initial value
)(
    input wire i_clk, i_arst_n,
    input wire i_init, i_calc,
    input wire [7:0] i_data,
    output wire [7:0] o_crc
);


    // function for calculate crc-8
    function [7:0] crc_calc(input reg [7:0] i_data, poly);
        reg[7:0] temp;
        integer i;
        begin
            temp = i_data;
            for (i=0; i < 8; i = i + 1) begin
                if (temp[7] == 1'b1)
                    temp = (temp << 1) ^ poly;
                else
                    temp = (temp << 1);
            end
            crc_calc = temp; // calculated crc value
        end
    endfunction         

    // ****************************************************************************
    // generate crc-lut
    wire [7:0] crc_lut [255:0];

    generate
        genvar i;
        for (i = 0; i < 256; i = i + 1) begin
            assign crc_lut[i] = crc_calc(i, POLY);
        end
    endgenerate

    // *****************************************************************************
    // crc-register output logic

    reg [7:0] r_crc;
    wire [7:0] ri_crc;

    always @ (posedge i_clk, negedge i_arst_n)
        if (~i_arst_n)
            r_crc <= INIT;
        else
            r_crc <= ri_crc;


    // next crc - logic
    assign ri_crc = (i_init) ? INIT : // init crc
                    (i_calc) ? crc_lut[(r_crc^i_data)] : // calc next crc
                               r_crc; // no change 

    // crc output
    assign o_crc = r_crc;

endmodule

`endif /* CRC_8 */









  
