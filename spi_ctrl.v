/*
 * Author:				Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:					spi_ctrl.v
 * Description:		SPI Controller
 * Organizations:	BSC; CIC-IPN
 */
module spi_ctrl
#	(
		parameter	FREQ_CLK	=	50000000,
		parameter	FREQ_SPI	=	2500000,
		parameter	BYTE			=	8
	)
(/*AUTOARG*/
   // Outputs
   spi_busy, spi_ready, spi_recv_data, spi_clk, spi_cs_n, spi_mosi,
   // Inputs
   iclk, spi_select, spi_msb_lsb_sel, spi_exchange, spi_send_data,
   spi_miso
   );

	/* ctrl */
	input								iclk;
	input								spi_select;
	input								spi_msb_lsb_sel;
	input								spi_exchange;
	output 							spi_busy;
	output							spi_ready;

	/* data */
	input		[BYTE-1:0]	spi_send_data;
	output	[BYTE-1:0]	spi_recv_data;

	/* spi */
	output							spi_clk;
	output							spi_cs_n;
	output							spi_mosi;
	input								spi_miso;

	/* regs, wires and assigns */
	wire				spi_clk_en;
	assign			spi_cs_n = spi_select;

	/* spi clock generator */
	spi_clk_gen
		#	(
				.FREQ_CLK	(FREQ_CLK),	//..50MHz
				.FREQ_SPI	(FREQ_SPI)	//..2.5MHz
			)
		spi_clk_gen_i0	(
			.iclk				(iclk),
			.ien				(spi_clk_en),
			.spi_clk		(spi_clk)
		);

	/* spi exchange byte module */
	spi_exch_byte
		#	(
				.BYTE			(BYTE)
			)
		spi_exch_byte_i0	(
			/* clks */
			.iclk					(iclk),
			.isclk				(spi_clk),

			/* ctrl */
			.imsb_lsb_sel	(spi_msb_lsb_sel),
			.iexchange		(spi_exchange),
			.osclk_en			(spi_clk_en),
			.obusy				(spi_busy),
			.oready				(spi_ready),

			/* data */
			.idata				(spi_send_data),
			.odata				(spi_recv_data),

			/* mosi/miso */
			.miso					(spi_miso),
			.mosi					(spi_mosi)
		);


endmodule
