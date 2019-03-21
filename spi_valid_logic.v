/*
 * Author:				Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:					spi_valid_logic.v
 * Description:		SPI Valid Data Logic
 * Organizations:	BSC; CIC-IPN
 */
module spi_valid_logic
#	(
		parameter DEPTH = 16
	)
(/*AUTOARG*/
   // Outputs
   ovalid, ofull, oempty,
   // Inputs
   iclk, irst, ipush, ipull
   );

	input 		iclk;
	input 		irst;

	input 		ipush;
	input 		ipull;

	output 		ovalid;
	output 		ofull;
	output 		oempty;

	/* regs and wires */
	reg 	[DEPTH-1:0]	valid_reg = 0;

	/* assignments */
	assign ovalid	=	valid_reg[0];
	assign ofull	=	valid_reg[DEPTH-1];
	assign oempty	=	~valid_reg[0];

	/* valid logic */
	always @ (posedge iclk) begin
		if(irst)
			valid_reg	<=	{DEPTH{1'b0}};
		else begin
			case({ipull,ipush})
				2'b01:	begin	//..push
					valid_reg[0]						<=	1'b1;
					valid_reg[1+:(DEPTH-1)]	<=	valid_reg[0+:(DEPTH-1)];	//..shift one bit to the left, set the lsb
				end
				2'b10:	begin	//..pull
					valid_reg[DEPTH-1]			<=	1'b0;
					valid_reg[0+:(DEPTH-1)]	<=	valid_reg[1+:(DEPTH-1)];	//..shift one bit to the right, clear the msb
				end
				default:	valid_reg	<=	valid_reg;
			endcase
		end
	end

endmodule // spi_valid_logic
