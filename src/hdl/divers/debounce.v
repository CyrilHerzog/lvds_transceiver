 
/*
    Module  : DEBOUNCE
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/



`ifndef _DEBOUNCE_V_
`define _DEBOUNCE_V_

module debounce
#(
	parameter
		WIDTH = 8
)
(
	input wire i_clk, i_arst_n, 
	input wire i_sig,
	output wire o_deb
);

(* fsm_encoding = "user_encoding" *)
localparam[1:0]
	s_0 = 2'b00,
	s_1 = 2'b01,
	s_2 = 2'b10,
	s_3 = 2'b11;


reg [1:0] r_state, ri_next_state;
reg [WIDTH-1:0] r_counter;
wire [WIDTH-1:0] ri_counter;
wire full;
reg r_deb;
wire ri_deb;
	
		
always@(posedge i_clk, negedge i_arst_n)
	if(~i_arst_n) begin
		r_state	  <= s_0;
		r_counter <= 0;
		r_deb     <= 1'b0;
		end
	else
		begin
		r_state   <= ri_next_state;
		r_counter <= ri_counter;
		r_deb     <= ri_deb;     //buffer
	end
		
assign ri_counter = (r_state[0]) ? r_counter + 1 : 0;
assign full = &r_counter;

always@ *
begin

	ri_next_state = r_state;

	case(r_state)
		s_0: 
		if(i_sig)
			ri_next_state = s_1;
			
		s_1: 
		if(~i_sig)
			ri_next_state = s_0;
		else
		if(full)
			ri_next_state = s_2;
			
		s_2:
		if(~i_sig)
			ri_next_state = s_3;
				
		s_3: 
		if(i_sig)
			ri_next_state = s_2;
		else if(full)
			ri_next_state = s_0;
		
	endcase
end

assign ri_deb = (r_state[1]) ? 1'b1 : 1'b0;
assign o_deb = r_deb;
			
endmodule			

`endif /* DEBOUNCE */