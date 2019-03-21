/*
 * Author:				Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:					spi_clk_gen.v
 * Description:		SPI Clock Generator
 * Organizations:	BSC; CIC-IPN
 */
module spi_clk_gen
#	(
		parameter FREQ_CLK 	= 100000000,	//..100MHz
		parameter FREQ_SPI	= 2000000			//..2MHz
	)
(/*AUTOARG*/
   // Outputs
   spi_clk,
   // Inputs
   iclk, ien
   );

	/* flow control */
	input				iclk;
	input				ien;

	/* spi clock */
	output reg	spi_clk = 0;

	localparam LIMIT	=	FREQ_CLK/(2*FREQ_SPI);

	reg	[31:0]	counter = 0;

	always @ (posedge iclk)	begin
		if(~ien)	begin
			counter	<=	0;
			spi_clk	<=	0;
		end
		else	begin
			if(counter==LIMIT)	begin
				counter	<=	0;
				spi_clk	<=	~spi_clk;
			end
			else
				counter	<=	counter + 1;
		end
	end

endmodule
