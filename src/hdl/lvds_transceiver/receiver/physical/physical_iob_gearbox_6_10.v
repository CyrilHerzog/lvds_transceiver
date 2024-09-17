/*
    Module  : PHYSICAL_IOB_GEARBOX_6_10
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _PHYSICAL_IOB_GEARBOX_6_10_V_
`define _PHYSICAL_IOB_GEARBOX_6_10_V_

`include "src/hdl/cdc/synchronizer.v"
`include "src/hdl/cdc/async_reset.v"

module physical_iob_gearbox_6_10 (
    input wire i_wr_clk, i_wr_arst_n,
    input wire i_rd_clk, i_rd_arst_n,
    input wire [3:0] i_slipbits,
    input wire [5:0] i_wr_data,
    output wire [9:0] o_rd_data
);

////////////////////////////////////////////////////////////////////////////////////
// LOCAL RESET
wire local_wr_arst_n;
wire local_rd_arst_n;

async_reset #(
    .STAGES   (2),
    .INIT     (1'b0),
    .RST_VAL  (1'b0)
) inst_local_reset_wr (
    .i_clk    (i_wr_clk), 
    .i_rst_n  (i_wr_arst_n),
    .o_rst    (local_wr_arst_n)
);

async_reset #(
    .STAGES   (2),
    .INIT     (1'b0),
    .RST_VAL  (1'b0)
) inst_local_reset_rd (
    .i_clk    (i_rd_clk), 
    .i_rst_n  (i_rd_arst_n),
    .o_rst    (local_rd_arst_n)
);



////////////////////////////////////////////////////////////////////////////////////
// WRITE POINTER

reg[3:0] r_wr_addr;
wire[3:0] ri_wr_addr;
reg r_rd_enable;
wire ri_rd_enable;

always@(posedge i_wr_clk, negedge local_wr_arst_n)
    if (~local_wr_arst_n) begin
        r_wr_addr   <= 4'b0000;
        r_rd_enable <= 1'b0;
    end else begin
        r_wr_addr   <= ri_wr_addr;
        r_rd_enable <= ri_rd_enable;
    end


assign ri_wr_addr = (r_wr_addr == 4'd14) ? 4'd0 : r_wr_addr + 4'd1;
//
assign ri_rd_enable = ((r_wr_addr == 2) | r_rd_enable);


// SYNCHRONIZER RD_ENABLE - WR_CLK <=> RD_CLK
    synchronizer #(
        .STAGES   (2),
        .INIT     (1'b0)
    ) inst_sync_read_enable (
        .i_clk    (i_rd_clk),
        .i_arst_n (local_rd_arst_n),
        .i_async  (r_rd_enable),
        .o_sync   () 
    );


////////////////////////////////////////////////////////////////////////////////////
// READ - POINTER FSM

reg[3:0] r_rd_addr_a, ri_rd_addr_a;
reg[3:0] r_rd_addr_b, ri_rd_addr_b;
reg[3:0] r_rd_addr_c, ri_rd_addr_c;
reg[1:0] r_mux_sel, ri_mux_sel;

always@(posedge i_rd_clk, negedge local_rd_arst_n)
    if (~local_rd_arst_n) begin
        r_rd_addr_a <= 4'b0000;
        r_rd_addr_b <= 4'b0001;
        r_rd_addr_c <= 4'b0000; 
        //
        r_mux_sel   <= 2'b00;
    end else begin
        r_rd_addr_a <= ri_rd_addr_a;
        r_rd_addr_b <= ri_rd_addr_b;
        r_rd_addr_c <= ri_rd_addr_c;
        //
        r_mux_sel   <= ri_mux_sel;
    end


always@ * begin
    
    //
    ri_rd_addr_a = r_rd_addr_a;
    ri_rd_addr_b = r_rd_addr_b;
    ri_rd_addr_c = r_rd_addr_c;
    //
    ri_mux_sel   = r_mux_sel;

    case({inst_sync_read_enable.o_sync, r_rd_addr_a})
        5'b10000: begin 
            ri_rd_addr_a = 4'b0010; 
            ri_rd_addr_c = 4'b0011; 
            ri_mux_sel   = 2'b01; 
        end

        5'b10010: begin 
            ri_rd_addr_a = 4'b0100; 
            ri_mux_sel   = 2'b10; 
        end

        5'b10100: begin 
            ri_rd_addr_a = 4'b0101; 
            ri_rd_addr_b = 4'b0110; 
            ri_mux_sel   = 2'b00; 
        end

        5'b10101: begin 
            ri_rd_addr_a = 4'b0111; 
            ri_rd_addr_c = 4'b1000; 
            ri_mux_sel   = 2'b01;
        end

        5'b10111: begin 
            ri_rd_addr_a = 4'b1001; 
            ri_mux_sel   = 2'b10; 
        end

        5'b11001: begin
            ri_rd_addr_a = 4'b1010;
            ri_rd_addr_b = 4'b1011;
            ri_mux_sel   = 2'b00;
        end

        5'b11010: begin
            ri_rd_addr_a = 4'b1100;
            ri_rd_addr_c = 4'b1101;
            ri_mux_sel   = 2'b01;
        end

        5'b11100: begin
            ri_rd_addr_a = 4'b1110;
            ri_mux_sel   = 2'b10;
        end

        default: begin 
            ri_rd_addr_a = 4'b0000; 
            ri_rd_addr_b = 4'b0001;
            ri_mux_sel   = 2'b00; 
        end
    endcase
end



/////////////////////////////////////////////////////////////////////////////////////////////////////
// RAM

reg [5:0] r_ram [14:0];

always@(posedge i_wr_clk)
    r_ram[r_wr_addr] <= i_wr_data;

////////////////////////////////////////////////////////////////////////////////////////////////////
// READ RAM 

reg[9:0] r_rd_data;
wire[9:0] ri_rd_data;

assign ri_rd_data[9:0] = r_mux_sel[1] ? {r_ram[r_rd_addr_a], r_ram[r_rd_addr_c][5:2]} : (r_mux_sel[0] ? 
                          {r_ram[r_rd_addr_c][1:0], r_ram[r_rd_addr_a], r_ram[r_rd_addr_b][5:4]} : 
                          {r_ram[r_rd_addr_b][3:0], r_ram[r_rd_addr_a]});



always@(posedge i_rd_clk, negedge local_rd_arst_n)
    if (~local_rd_arst_n)
        r_rd_data <= 10'b0000000000;
    else
        r_rd_data <= ri_rd_data;
    

/////////////////////////////////////////////////////////////////////////////////////////////////////
// BITSLIP

reg[19:0] r_temp;
wire[19:0] ri_temp;
//
reg[9:0] r_rd_data_o, ri_rd_data_o;
//
reg[3:0] r_slipbits;


always@(posedge i_rd_clk, negedge local_rd_arst_n)
    if (~local_rd_arst_n) begin
        r_temp      <= 20'd0;
        r_rd_data_o <= 10'd0;
        r_slipbits  <= 4'b0000;
    end else begin
        r_temp      <= ri_temp;
        r_rd_data_o <= ri_rd_data_o;
        //
        r_slipbits  <= i_slipbits;
    end

//
assign ri_temp[19:10] = r_rd_data;
assign ri_temp[9:0]   = r_temp[19:10];

always@ * begin

    //
    ri_rd_data_o = r_rd_data_o;

    //
    case(r_slipbits)
        4'd1: begin ri_rd_data_o = r_temp[10:1]; end
        4'd2: begin ri_rd_data_o = r_temp[11:2]; end
        4'd3: begin ri_rd_data_o = r_temp[12:3]; end
        4'd4: begin ri_rd_data_o = r_temp[13:4]; end
        4'd5: begin ri_rd_data_o = r_temp[14:5]; end
        4'd6: begin ri_rd_data_o = r_temp[15:6]; end
        4'd7: begin ri_rd_data_o = r_temp[16:7]; end
        4'd8: begin ri_rd_data_o = r_temp[17:8]; end
        4'd9: begin ri_rd_data_o = r_temp[18:9]; end
        // 4'd0 or out of range 0 - 9
        default: begin ri_rd_data_o = r_temp[9:0]; end
    endcase

end

//
assign o_rd_data = r_rd_data_o;


endmodule

`endif

