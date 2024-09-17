
 /*
    Module  : SYNC_DUAL_PORT_RAM
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _SYNC_DUAL_PORT_RAM_V_
`define _SYNC_DUAL_PORT_RAM_V_

module sync_dual_port_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3
)(

    input wire i_clk,
    input wire i_wr,
    input wire [ADDR_WIDTH-1:0] i_addr_a,
    input wire [ADDR_WIDTH-1:0] i_addr_b,
    input wire [DATA_WIDTH-1:0] i_data,
    output wire [DATA_WIDTH-1:0] o_data_a,
    output wire [DATA_WIDTH-1:0] o_data_b
);

        
    reg [DATA_WIDTH-1:0] r_ram [(2**ADDR_WIDTH)-1:0];
    reg [ADDR_WIDTH-1:0] r_addr_a, r_addr_b;

    // ram init
    integer i;
    initial begin
        // clear ram
        for (i = 0; i < (2**ADDR_WIDTH); i = i + 1) begin
            r_ram[i] = 0;
        end
    end
   
    always @(posedge i_clk) 
    begin
        if (i_wr)
            r_ram [i_addr_a] <= i_data;
        
        r_addr_a <= i_addr_a;
        r_addr_b <= i_addr_b;    
    end

    // synchronous read
    assign o_data_a = r_ram [r_addr_a];
    assign o_data_b = r_ram [r_addr_b];

endmodule

`endif /* SYNC_DUAL_PORT_RAM */