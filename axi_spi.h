/*
 * Author:				Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:					axi_spi.h
 * Description:		AXI4-Lite SPI Header file
 * Organizations:	BSC; CIC-IPN
 */

	/* axi spi register map */
	localparam	SPI_GIER	=	7'h1c;
	localparam	SPI_ISR		=	7'h20;
	localparam	SPI_IER		=	7'h28;
	localparam	SPI_SRR		=	7'h40;
	localparam	SPI_CR		=	7'h60;
	localparam	SPI_SR		=	7'h64;
	localparam	SPI_DTR		=	7'h68;
	localparam	SPI_DRR		=	7'h6c;
	localparam	SPI_SSR		=	7'h70;
	localparam	SPI_TFOR	=	7'h74;
	localparam	SPI_RFOR	=	7'h78;

	/* axi spi parameters (reset values) */
	localparam	SPI_CR_Init		=	32'h00000180;
	localparam	SPI_SR_Init		=	32'h000000a5;
	localparam	SPI_SSR_Init	=	32'hffffffff;
	localparam	SPI_TFOR_Init	=	32'h00000000;
	localparam	SPI_RFOR_Init	=	32'h00000000;
	localparam	SPI_GIER_Init	=	32'h00000000;
	localparam	SPI_ISR_Init	=	32'h00000000;
	localparam	SPI_IER_Init	=	32'h00000000;

	/* axi spi soft reset register value */
	localparam	SPI_SRR_Value	=	32'h0000000a;

	/* axi spi parameters */
	localparam	FREQ_SPI							=	12500000;
	localparam	DATA_WIDTH_SPI				=	8;

	/* axi spi control bits */
	localparam	CR_LSB_FIRST_BIT			=	9;
	localparam	CR_RX_FIFO_RESET_BIT	=	6;
	localparam	CR_TX_FIFO_RESET_BIT	=	5;
	localparam	CR_CPHA_BIT						=	4;
	localparam	CR_CPOL_BIT						=	3;
	localparam	CR_MASTER_BIT					=	2;
	localparam	CR_SPI_ENABLE_BIT			=	1;

	/* axi spi status bits */
	localparam	SR_RX_EMPTY_BIT				=	0;
	localparam	SR_RX_FULL_BIT				=	1;
	localparam	SR_TX_EMPTY_BIT				=	2;
	localparam	SR_TX_FULL_BIT				=	3;
	localparam	SR_MODF_BIT						=	4;
	localparam	SR_SMOD_SEL_BIT				=	5;
