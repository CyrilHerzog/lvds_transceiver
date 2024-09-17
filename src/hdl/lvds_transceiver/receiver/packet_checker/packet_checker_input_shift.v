/*
    Module  : PACKET_CHECKER_INPUT_SHIFT
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _PACKET_CHECKER_INPUT_SHIFT_V_
`define _PACKET_CHECKER_INPUT_SHIFT_V_


module packet_checker_input_shift #(
    parameter STAGES = 2
)(
    input wire i_clk,
    input wire i_enable,
    input wire [7:0] i_byte, 
    output wire[(STAGES << 3)-1:0] o_frame
);

   
    //////////////////////////////////////////////////////////////////////////////////
    // GENERATE SHIFT - STAGES

    reg [7:0] r_stage [0:(STAGES-1)];      
    wire [7:0] ri_stage [0:(STAGES-1)];
    

    integer k;

    initial begin
        // clear stages
        for (k = 0; k < STAGES; k = k + 1) begin
            r_stage[k] = 0;
        end
    end

    always @ (posedge i_clk) begin
        for (k=0; k < STAGES; k = k + 1) begin  
            r_stage[k] <= ri_stage[k];
        end        
    end

    genvar i;
    generate
        // shift register
        assign ri_stage[0] = (i_enable) ? i_byte : r_stage[0];
        for (i = 1; i < STAGES; i = i + 1) begin
            assign ri_stage[i] = (i_enable) ? r_stage[i - 1] : r_stage[i];
        end

        // assign register to tlp-frame
        for (i = 0; i < STAGES; i = i + 1) begin
            assign o_frame[(7 + (i * 8)): (i * 8)] = r_stage[i];
        end

    endgenerate 
 

endmodule

`endif /* PACKET_CHECKER_INPUT_SHIFT */