

// gearbox xapp 1017

module gearbox_4_to_10 (input_clock, output_clock, datain, reset, slip_bits, dataout) ;

parameter integer 		D = 8 ;   		// Set the number of inputs

input				input_clock ;		// high speed clock input
input				output_clock ;		// low speed clock input
input		[D*4-1:0]	datain ;		// data inputs
input				reset ;			// Reset line
input		[3:0]		slip_bits ;		// selects the number of bits to slip 0 - 9
output	reg	[D*10-1:0]	dataout ;		// data outputs
					
reg	[4:0]		read_addra ;				
reg	[4:0]		read_addrb ;				
reg	[4:0]		read_addrc ;				
reg	[4:0]		read_addrd ;				
reg	[4:0]		write_addr ;				
reg			read_enable ;		
reg			read_enabler ;		
wire	[D*4-1:0]	ramouta ; 				
wire	[D*4-1:0]	ramoutb ; 				
wire	[D*4-1:0]	ramoutc ; 				
wire	[D-1:0]		ramoutd ; 				
reg			local_reset ;		
reg	[1:0]		mux ;			
reg	[D*10-1:0]	muxone ;
reg	[D*10-1:0]	muxtwo ;
wire	[D*4-1:0]	dummy ;			
reg	[3:0]		slip_bits_int ;
				
always @ (posedge input_clock) begin				// generate local sync (rxclk_div116) reset
	if (reset == 1'b1) begin
		local_reset <= 1'b1 ;
	end
	else begin
		local_reset <= 1'b0 ;
	end
end 

always @ (posedge input_clock) begin				// Gearbox input - 4 bit data at input clock frequency
	if (local_reset == 1'b1) begin
		write_addr <= 5'b00000 ;
		read_enable <= 1'b0 ;
	end
	else if (write_addr == 5'b01110) begin
		write_addr <= 5'b00000 ;
	end
	else begin
		write_addr <= write_addr + 5'h01 ;
	end
	if (write_addr == 5'b00011) begin
		read_enable <= 1'b1 ;
	end
end

always @ (posedge output_clock) begin				// Gearbox output - 10 bit data at output clock frequency
	read_enabler <= read_enable ;
	if (read_enabler == 1'b0) begin
		read_addra <= 5'b00000 ;
		read_addrb <= 5'b00001 ;
		read_addrc <= 5'b00010 ;
		read_addrd <= 5'b00011 ;
		slip_bits_int <= 4'h0 ;
	end
	else begin
		case (slip_bits_int)	
			5'h00 : begin
				case (read_addra) 
					5'b00000 : begin read_addra <= 5'b00010 ; read_addrb <= 5'b00011 ; read_addrc <= 5'b00100 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
					5'b00010 : begin read_addra <= 5'b00101 ; read_addrb <= 5'b00110 ; read_addrc <= 5'b00111 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
					5'b00101 : begin read_addra <= 5'b00111 ; read_addrb <= 5'b01000 ; read_addrc <= 5'b01001 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
					5'b00111 : begin read_addra <= 5'b01010 ; read_addrb <= 5'b01011 ; read_addrc <= 5'b01100 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
					5'b01010 : begin read_addra <= 5'b01100 ; read_addrb <= 5'b01101 ; read_addrc <= 5'b01110 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; slip_bits_int <= slip_bits ; end
					default  : begin read_addra <= 5'b00000 ; read_addrb <= 5'b00001 ; read_addrc <= 5'b00010 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
				endcase 
			end
			5'h01 : begin
				case (read_addra) 
					5'b00000 : begin read_addra <= 5'b00010 ; read_addrb <= 5'b00011 ; read_addrc <= 5'b00100 ; read_addrd <= 5'b00101 ; mux <= 2'h3 ; end
					5'b00010 : begin read_addra <= 5'b00101 ; read_addrb <= 5'b00110 ; read_addrc <= 5'b00111 ; read_addrd <= 5'b01000 ; mux <= 2'h2 ; end
					5'b00101 : begin read_addra <= 5'b00111 ; read_addrb <= 5'b01000 ; read_addrc <= 5'b01001 ; read_addrd <= 5'b01010 ; mux <= 2'h3 ; end
					5'b00111 : begin read_addra <= 5'b01010 ; read_addrb <= 5'b01011 ; read_addrc <= 5'b01100 ; read_addrd <= 5'b01101 ; mux <= 2'h2 ; end
					5'b01010 : begin read_addra <= 5'b01100 ; read_addrb <= 5'b01101 ; read_addrc <= 5'b01110 ; read_addrd <= 5'b00000 ; mux <= 2'h3 ; slip_bits_int <= slip_bits ; end
					default  : begin read_addra <= 5'b00000 ; read_addrb <= 5'b00001 ; read_addrc <= 5'b00010 ; read_addrd <= 5'b00011 ; mux <= 2'h2 ; end
				endcase 
			end
			5'h02 : begin
				case (read_addra) 
					5'b00000 : begin read_addra <= 5'b00011 ; read_addrb <= 5'b00100 ; read_addrc <= 5'b00101 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
					5'b00011 : begin read_addra <= 5'b00101 ; read_addrb <= 5'b00110 ; read_addrc <= 5'b00111 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
					5'b00101 : begin read_addra <= 5'b01000 ; read_addrb <= 5'b01001 ; read_addrc <= 5'b01010 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
					5'b01000 : begin read_addra <= 5'b01010 ; read_addrb <= 5'b01011 ; read_addrc <= 5'b01100 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
					5'b01010 : begin read_addra <= 5'b01101 ; read_addrb <= 5'b01110 ; read_addrc <= 5'b00000 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; slip_bits_int <= slip_bits ; end
					default  : begin read_addra <= 5'b00000 ; read_addrb <= 5'b00001 ; read_addrc <= 5'b00010 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
				endcase 
			end
			5'h03 : begin
				case (read_addra) 
					5'b00000 : begin read_addra <= 5'b00011 ; read_addrb <= 5'b00100 ; read_addrc <= 5'b00101 ; read_addrd <= 5'b00110 ; mux <= 2'h2 ; end
					5'b00011 : begin read_addra <= 5'b00101 ; read_addrb <= 5'b00110 ; read_addrc <= 5'b00111 ; read_addrd <= 5'b01000 ; mux <= 2'h3 ; end
					5'b00101 : begin read_addra <= 5'b01000 ; read_addrb <= 5'b01001 ; read_addrc <= 5'b01010 ; read_addrd <= 5'b01011 ; mux <= 2'h2 ; end
					5'b01000 : begin read_addra <= 5'b01010 ; read_addrb <= 5'b01011 ; read_addrc <= 5'b01100 ; read_addrd <= 5'b01101 ; mux <= 2'h3 ; end
					5'b01010 : begin read_addra <= 5'b01101 ; read_addrb <= 5'b01110 ; read_addrc <= 5'b00000 ; read_addrd <= 5'b00000 ; mux <= 2'h2 ; slip_bits_int <= slip_bits ; end
					default  : begin read_addra <= 5'b00000 ; read_addrb <= 5'b00001 ; read_addrc <= 5'b00010 ; read_addrd <= 5'b00011 ; mux <= 2'h3 ; end
				endcase 
			end
			5'h04 : begin
				case (read_addra) 
					5'b00001 : begin read_addra <= 5'b00011 ; read_addrb <= 5'b00100 ; read_addrc <= 5'b00101 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
					5'b00011 : begin read_addra <= 5'b00110 ; read_addrb <= 5'b00111 ; read_addrc <= 5'b01000 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
					5'b00110 : begin read_addra <= 5'b01000 ; read_addrb <= 5'b01001 ; read_addrc <= 5'b01010 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
					5'b01000 : begin read_addra <= 5'b01011 ; read_addrb <= 5'b01100 ; read_addrc <= 5'b01101 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
					5'b01011 : begin read_addra <= 5'b01101 ; read_addrb <= 5'b01110 ; read_addrc <= 5'b00000 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; slip_bits_int <= slip_bits ; end
					default  : begin read_addra <= 5'b00001 ; read_addrb <= 5'b00010 ; read_addrc <= 5'b00011 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
				endcase 
			end
			5'h05 : begin
				case (read_addra) 
					5'b00001 : begin read_addra <= 5'b00011 ; read_addrb <= 5'b00100 ; read_addrc <= 5'b00101 ; read_addrd <= 5'b00110 ; mux <= 2'h3 ; end
					5'b00011 : begin read_addra <= 5'b00110 ; read_addrb <= 5'b00111 ; read_addrc <= 5'b01000 ; read_addrd <= 5'b01001 ; mux <= 2'h2 ; end
					5'b00110 : begin read_addra <= 5'b01000 ; read_addrb <= 5'b01001 ; read_addrc <= 5'b01010 ; read_addrd <= 5'b01011 ; mux <= 2'h3 ; end
					5'b01000 : begin read_addra <= 5'b01011 ; read_addrb <= 5'b01100 ; read_addrc <= 5'b01101 ; read_addrd <= 5'b01110 ; mux <= 2'h2 ; end
					5'b01011 : begin read_addra <= 5'b01101 ; read_addrb <= 5'b01110 ; read_addrc <= 5'b00000 ; read_addrd <= 5'b00001 ; mux <= 2'h3 ; slip_bits_int <= slip_bits ; end
					default  : begin read_addra <= 5'b00001 ; read_addrb <= 5'b00010 ; read_addrc <= 5'b00011 ; read_addrd <= 5'b00100 ; mux <= 2'h2 ; end
				endcase 
			end
			5'h06 : begin
				case (read_addra) 
					5'b00001 : begin read_addra <= 5'b00100 ; read_addrb <= 5'b00101 ; read_addrc <= 5'b00110 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
					5'b00100 : begin read_addra <= 5'b00110 ; read_addrb <= 5'b00111 ; read_addrc <= 5'b01000 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
					5'b00110 : begin read_addra <= 5'b01001 ; read_addrb <= 5'b01010 ; read_addrc <= 5'b01011 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
					5'b01001 : begin read_addra <= 5'b01011 ; read_addrb <= 5'b01100 ; read_addrc <= 5'b01101 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
					5'b01011 : begin read_addra <= 5'b01110 ; read_addrb <= 5'b00000 ; read_addrc <= 5'b00001 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; slip_bits_int <= slip_bits ; end
					default  : begin read_addra <= 5'b00001 ; read_addrb <= 5'b00010 ; read_addrc <= 5'b00011 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
				endcase 
			end
			5'h07 : begin
				case (read_addra) 
					5'b00001 : begin read_addra <= 5'b00100 ; read_addrb <= 5'b00101 ; read_addrc <= 5'b00110 ; read_addrd <= 5'b00111 ; mux <= 2'h2 ; end
					5'b00100 : begin read_addra <= 5'b00110 ; read_addrb <= 5'b00111 ; read_addrc <= 5'b01000 ; read_addrd <= 5'b01001 ; mux <= 2'h3 ; end
					5'b00110 : begin read_addra <= 5'b01001 ; read_addrb <= 5'b01010 ; read_addrc <= 5'b01011 ; read_addrd <= 5'b01100 ; mux <= 2'h2 ; end
					5'b01001 : begin read_addra <= 5'b01011 ; read_addrb <= 5'b01100 ; read_addrc <= 5'b01101 ; read_addrd <= 5'b01110 ; mux <= 2'h3 ; end
					5'b01011 : begin read_addra <= 5'b01110 ; read_addrb <= 5'b00000 ; read_addrc <= 5'b00001 ; read_addrd <= 5'b00010 ; mux <= 2'h2 ; slip_bits_int <= slip_bits ; end
					default  : begin read_addra <= 5'b00001 ; read_addrb <= 5'b00010 ; read_addrc <= 5'b00011 ; read_addrd <= 5'b00100 ; mux <= 2'h3 ; end
				endcase 
			end
			5'h08 : begin
				case (read_addra) 
					5'b00010 : begin read_addra <= 5'b00100 ; read_addrb <= 5'b00101 ; read_addrc <= 5'b00110 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
					5'b00100 : begin read_addra <= 5'b00111 ; read_addrb <= 5'b01000 ; read_addrc <= 5'b01001 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
					5'b00111 : begin read_addra <= 5'b01001 ; read_addrb <= 5'b01010 ; read_addrc <= 5'b01011 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; end
					5'b01001 : begin read_addra <= 5'b01100 ; read_addrb <= 5'b01101 ; read_addrc <= 5'b01110 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
					5'b01100 : begin read_addra <= 5'b01110 ; read_addrb <= 5'b00000 ; read_addrc <= 5'b00001 ; read_addrd <= 5'bXXXXX ; mux <= 2'h1 ; slip_bits_int <= slip_bits ; end
					default  : begin read_addra <= 5'b00010 ; read_addrb <= 5'b00011 ; read_addrc <= 5'b00100 ; read_addrd <= 5'bXXXXX ; mux <= 2'h0 ; end
				endcase 
			end
			default : begin
				case (read_addra) 
					5'b00010 : begin read_addra <= 5'b00100 ; read_addrb <= 5'b00101 ; read_addrc <= 5'b00110 ; read_addrd <= 5'b00111 ; mux <= 2'h3 ; end
					5'b00100 : begin read_addra <= 5'b00111 ; read_addrb <= 5'b01000 ; read_addrc <= 5'b01001 ; read_addrd <= 5'b01010 ; mux <= 2'h2 ; end
					5'b00111 : begin read_addra <= 5'b01001 ; read_addrb <= 5'b01010 ; read_addrc <= 5'b01011 ; read_addrd <= 5'b01100 ; mux <= 2'h3 ; end
					5'b01001 : begin read_addra <= 5'b01100 ; read_addrb <= 5'b01101 ; read_addrc <= 5'b01110 ; read_addrd <= 5'b00000 ; mux <= 2'h2 ; end
					5'b01100 : begin read_addra <= 5'b01110 ; read_addrb <= 5'b00000 ; read_addrc <= 5'b00001 ; read_addrd <= 5'b00010 ; mux <= 2'h3 ; slip_bits_int <= slip_bits ; end
					default  : begin read_addra <= 5'b00010 ; read_addrb <= 5'b00011 ; read_addrc <= 5'b00100 ; read_addrd <= 5'b00101 ; mux <= 2'h2 ; end
				endcase 
			end
		endcase
	end 
end 

genvar i ;
generate 
for (i = 0 ; i <= D-1 ; i = i+1) begin : loop0 

always @ (posedge output_clock) begin
	case (mux) 
		2'h0    : dataout[10*i+9:10*i] <= {ramoutc[4*i+1:4*i+0], ramoutb[4*i+3:4*i+0], ramouta[4*i+3:4*i+0]} ;
		2'h1    : dataout[10*i+9:10*i] <= {ramoutc[4*i+3:4*i+0], ramoutb[4*i+3:4*i+0], ramouta[4*i+3:4*i+2]} ;		
		2'h2    : dataout[10*i+9:10*i] <= {ramoutc[4*i+2:4*i+0], ramoutb[4*i+3:4*i+0], ramouta[4*i+3:4*i+1]} ;		
		default : dataout[10*i+9:10*i] <= {ramoutd[i], ramoutc[4*i+3:4*i+0], ramoutb[4*i+3:4*i+0], ramouta[4*i+3]} ;
	endcase
end

end
endgenerate 
			     	
// Data gearboxes

generate
for (i = 0 ; i <= D*2-1 ; i = i+1)
begin : loop2

RAM32M ram_inst ( 
	.DOA	(ramouta[2*i+1:2*i]), 
	.DOB	(ramoutb[2*i+1:2*i]),
	.DOC    (ramoutc[2*i+1:2*i]), 
	.DOD    (dummy[2*i+1:2*i]),
	.ADDRA	(read_addra), 
	.ADDRB	(read_addrb), 
	.ADDRC  (read_addrc), 
	.ADDRD  (write_addr),
	.DIA	(datain[2*i+1:2*i]), 
	.DIB	(datain[2*i+1:2*i]),
	.DIC    (datain[2*i+1:2*i]),
	.DID    (dummy[2*i+1:2*i]),
	.WE 	(1'b1), 
	.WCLK	(input_clock));

if (i % 2 == 0) begin

RAM32X1D ram_instd (
	.D		(datain[2*i]),		// Fifo C
	.DPO		(ramoutd[i/2]), 
	.SPO		(), 
	.A4 		(write_addr[4]), 
	.A3 		(write_addr[3]), 
	.A2 		(write_addr[2]), 
	.A1 		(write_addr[1]), 
	.A0 		(write_addr[0]), 
	.DPRA4 		(read_addrd[4]), 
	.DPRA3 		(read_addrd[3]), 
	.DPRA2 		(read_addrd[2]), 
	.DPRA1 		(read_addrd[1]), 
	.DPRA0 		(read_addrd[0]), 
	.WCLK		(input_clock), 
	.WE		(1'b1)) ;
end
end
endgenerate 

endmodule
