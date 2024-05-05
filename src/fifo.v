`timescale 1ns/1ps

module fifo(
 	input clk,rst,
	input wr,rd,
	input [7:0] din,
	output reg [7:0] dout,
	output full,empty  
);

	reg [3:0] wptr;            // write pointer
	reg [3:0] rptr;              // read pointer
	reg [4:0] count;           
	reg [7:0] FIFO [0:15];     // Fifo memory

	always @(posedge clk)
	begin
		if(rst)
		begin
			wptr <= 'h0;
			rptr <= 'h0;
			count <= 'h0;
		end
		else if(wr && !full)
		begin
			FIFO[wptr] <= din;
			wptr <= wptr + 'h1;
			count <= count + 'h1;
		end
		else if(rd && !empty)
		begin
			dout <= FIFO[rptr];
			rptr <= rptr + 'h1;
			count <= count - 'h1;
		end
	end


	assign empty = (count == 'h0);
	assign full = (count == 'h10);

endmodule