/* -------------------------------------------------------------------------------
 * Project        : AXI-lite SPI IP Core
 * File           : axi_spi_defines.vh
 * Description    : AXI4-Lite SPI parameters defines
 * Organization   : BSC; CIC-IPN
 * Author(s)      : Abraham J. Ruiz R. (aruiz) (https://github.com/m4j0rt0m)
 * Email(s)       : abraham.ruiz@bsc.es; abraham.j.ruiz.r@gmail.com
 * References     :
 * -------------------------------------------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  1.0        | aruiz       | First version
 *  2.0        | aruiz       | Added asynchronous reset and soft reset
 *  2.1        | aruiz       | Code refactoring and added Ratio Clock Gen
 * -----------------------------------------------------------------------------*/

  `ifndef _AXI_SPI_DEFINES_
  `define _AXI_SPI_DEFINES_

  `define _AXI_SPI_DATA_WIDTH_  32
  `define _AXI_SPI_ADDR_WIDTH_  7
  `define _AXI_SPI_FIFO_DEPTH_  32
  `define _AXI_SPI_RESP_WIDTH_  2
  `define _AXI_SPI_ID_WIDTH_    12

  `endif
