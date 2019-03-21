/*
 * Author:				Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:					spi_exch_byte.v
 * Description:		SPI mosi/miso data exchange control
 * Organizations:	BSC; CIC-IPN
 */
module spi_exch_byte
#	(
		parameter	BYTE	=	8
	)
(/*AUTOARG*/
   // Outputs
   osclk_en, obusy, oready, odata, mosi,
   // Inputs
   iclk, isclk, imsb_lsb_sel, iexchange, idata, miso
   );

	/* clks */
	input										iclk;
	input										isclk;

	/* ctrl */
	input										imsb_lsb_sel;
	input										iexchange;
	output reg							osclk_en = 0;
	output reg							obusy = 0;
	output reg							oready = 0;

	/* data */
	input				[BYTE-1:0]	idata;
	output reg	[BYTE-1:0]	odata = 0;

	/* mosi/miso */
	input										miso;
	output reg							mosi = 0;

	/* integers and genvars */
	integer i;
	genvar I;

	/* local parameters */
	localparam	POS_EDGE	=	1'b0;
	localparam	NEG_EDGE	=	1'b1;
	localparam	DISABLED	=	1'b0;
	localparam	ENABLED		=	1'b1;
	localparam	IDLE			=	1'b0;
	localparam	BUSY			=	1'b1;
	localparam	HIGH			=	1'b1;
	localparam	LOW				=	1'b0;
	localparam	MSB				=	1'b0;
	localparam	LSB				=	1'b1;

	/* state machine parameters */
	reg	[2:0]	fsm_exch_byte;
		localparam	StateInit			=	3'b000;
		localparam	StateIdle			=	3'b011;
		localparam	StateExchange	=	3'b101;
			initial fsm_exch_byte	=	StateInit;

	/* regs and wires */
	reg		[BYTE-1:0]	buffer_r = 0;
	reg		[BYTE-1:0]	buffer_w = 0;
	reg		[BYTE-1:0]	bitcount = 0;
	reg								check_sdclk_edge = 0;
	wire	[BYTE-1:0]	data_s;	//..data to be send
	wire	[BYTE-1:0]	data_r;	//..data received
	wire	[BYTE-1:0]	data_s_i;
	wire	[BYTE-1:0]	buffer_r_i;

	/* state machine */
	always @ (posedge iclk)	begin
		case(fsm_exch_byte)
			StateInit:		begin
				osclk_en					<=	DISABLED;
				obusy							<=	IDLE;
				oready						<=	LOW;
				check_sdclk_edge	<=	POS_EDGE;
				mosi							<=	HIGH;
				fsm_exch_byte			<=	StateIdle;
			end
			StateIdle:		begin
				if(iexchange)			begin
					osclk_en					<=	ENABLED;
					obusy							<=	BUSY;
					bitcount					<=	0;
					check_sdclk_edge	<=	POS_EDGE;
					buffer_w					<=	data_s;
					mosi							<=	data_s[0];
					fsm_exch_byte			<=	StateExchange;
				end
				oready					<=	LOW;
			end
			StateExchange:		begin
				case(check_sdclk_edge)
					POS_EDGE:	begin
						if(isclk)	begin
							buffer_r[BYTE-1]		<=	miso;
							buffer_r[BYTE-2:0]	<=	buffer_r[BYTE-1:1];
							check_sdclk_edge		<=	NEG_EDGE;
						end
					end
					NEG_EDGE:	begin
						if(~isclk)	begin
							bitcount					<=	bitcount + 1;
							check_sdclk_edge	<=	POS_EDGE;
							if(&bitcount[2:0])	begin
								osclk_en					<=	DISABLED;
								obusy							<=	IDLE;
								odata							<=	data_r;
								mosi							<=	HIGH;
								oready						<=	HIGH;
								fsm_exch_byte			<=	StateIdle;
							end
							else	begin
								mosi							<=	buffer_w[1];
								buffer_w[6:1]			<=	buffer_w[7:2];
							end
						end
					end
				endcase
			end
			default: fsm_exch_byte <= fsm_exch_byte;
		endcase
	end

	/* MSB/LSB */
	generate
		for(I=0; I<BYTE; I=I+1)	begin:	rev_data_gen
			assign data_s_i[I] = idata[BYTE-I-1];
			assign buffer_r_i[I] = buffer_r[BYTE-I-1];
		end
	endgenerate
	assign data_s	=	(imsb_lsb_sel==MSB) ? data_s_i		: idata;
	assign data_r = (imsb_lsb_sel==MSB) ? buffer_r_i	: buffer_r;

endmodule
