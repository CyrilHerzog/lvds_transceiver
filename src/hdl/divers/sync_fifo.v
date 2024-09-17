 /*
    Module  : SYNC_FIFO
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/



`ifndef _SYNC_FIFO_V_
`define _SYNC_FIFO_V_

module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3
)(
    input wire i_clk, i_arst_n,
    input wire i_wr, i_rd,
    input wire [DATA_WIDTH-1:0] i_data,
    output wire [DATA_WIDTH-1:0] o_data,
    output wire o_full, o_empty
);
 

    reg [DATA_WIDTH-1:0] r_ram [(2**ADDR_WIDTH)-1:0];
    reg [ADDR_WIDTH:0] r_wr_ptr, r_rd_ptr;    
    wire [ADDR_WIDTH:0] ri_wr_ptr, ri_rd_ptr; 
    reg r_empty, r_full;
    wire ram_wr, ri_empty, ri_full;


    // bram
    integer i;
    initial begin
        // clear register-file
        for (i = 0; i < (2**ADDR_WIDTH); i = i + 1) begin
            r_ram[i] = 0;
        end
    end

    always@(posedge i_clk)
        if (ram_wr)
            r_ram[r_wr_ptr[ADDR_WIDTH-1:0]] <= i_data;


    assign o_data = r_ram[r_rd_ptr[ADDR_WIDTH-1:0]];
    assign ram_wr = i_wr & ~r_full; 
        

    always@(posedge i_clk, negedge i_arst_n)
        if (~i_arst_n) begin
            r_wr_ptr <= 0;
            r_rd_ptr <= 0;
            r_empty  <= 1'b1;
            r_full   <= 1'b0;
        end else begin
            r_wr_ptr <= ri_wr_ptr;
            r_rd_ptr <= ri_rd_ptr;
            r_empty  <= ri_empty;
            r_full   <= ri_full;
        end

    // address incrementer
    assign ri_wr_ptr = (i_wr && ~r_full) ? r_wr_ptr + 1 : r_wr_ptr;
    assign ri_rd_ptr = (i_rd && ~r_empty) ? r_rd_ptr + 1 : r_rd_ptr;

    // output buffer (lookahead)
    assign ri_empty = (ri_wr_ptr == ri_rd_ptr);
    assign ri_full =  (ri_wr_ptr[ADDR_WIDTH] ^ ri_rd_ptr[ADDR_WIDTH]) & 
                      (ri_wr_ptr[ADDR_WIDTH-1:0] == ri_rd_ptr[ADDR_WIDTH-1:0]);
    
    // assign outputs
    assign o_empty = r_empty;
    assign o_full  = r_full;

endmodule

`endif /* SYNC_FIFO */