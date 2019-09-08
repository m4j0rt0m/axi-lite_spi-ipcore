/*
 * Author:        Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:          axi_spi.h
 * Description:   AXI4-Lite SPI Header file
 * Organizations: BSC; CIC-IPN
 */

  `ifndef _AXI_SPI_H_
  `define _AXI_SPI_H_

  /* axi spi register map */
  `define _SPI_GIER_    7'h1c
  `define _SPI_ISR_     7'h20
  `define _SPI_IER_     7'h28
  `define _SPI_SRR_     7'h40
  `define _SPI_CR_      7'h60
  `define _SPI_SR_      7'h64
  `define _SPI_DTR_     7'h68
  `define _SPI_DRR_     7'h6c
  `define _SPI_SSR_     7'h70
  `define _SPI_TFOR_    7'h74
  `define _SPI_RFOR_    7'h78
  //  custom registers
  `define _SPI_RCLK_    7'h30

  /* axi spi parameters (reset values) */
  `define _SPI_CR_INIT_   32'h00000180
  `define _SPI_SR_INIT_   32'h000000a5
  `define _SPI_SSR_INIT_  32'hffffffff
  `define _SPI_TFOR_INIT_ 32'h00000000
  `define _SPI_RFOR_INIT_ 32'h00000000
  `define _SPI_GIER_INIT_ 32'h00000000
  `define _SPI_ISR_INIT_  32'h00000000
  `define _SPI_IER_INIT_  32'h00000000
  //  custom registers (reset values)
  `define _SPI_RCLK_INIT_ 1

  /* axi spi soft reset register value */
  `define _SPI_SRR_VALUE_ 32'h0000000a

  /* axi spi parameters */
  `define _DATA_WIDTH_SPI_  8
  `define _SPI_RATIO_GRADE_ 3

  /* axi spi control bits */
  `define _CR_LSB_FIRST_BIT_      9
  `define _CR_RX_FIFO_RESET_BIT_  6
  `define _CR_TX_FIFO_RESET_BIT_  5
  `define _CR_CPHA_BIT_           4
  `define _CR_CPOL_BIT_           3
  `define _CR_MASTER_BIT_         2
  `define _CR_SPI_ENABLE_BIT_     1

  /* axi spi status bits */
  `define _SR_RX_EMPTY_BIT_       0
  `define _SR_RX_FULL_BIT_        1
  `define _SR_TX_EMPTY_BIT_       2
  `define _SR_TX_FULL_BIT_        3
  `define _SR_MODF_BIT_           4
  `define _SR_SMOD_SEL_BIT_       5

  `endif
