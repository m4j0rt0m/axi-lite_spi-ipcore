/* -------------------------------------------------------------------------------
 * Project        : AXI-lite SPI IP Core
 * File           : spi_clk_gen.v
 * Description    : SPI Clock Generator
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

module spi_clk_gen
# (
    parameter SPI_RATIO_GRADE = 3
  )
(/*AUTOARG*/
   // Outputs
   spi_clk_o,
   // Inputs
   clk_i, arst_n_i, en_i, ratio_i
   );

  /* ports */
  input                       clk_i;
  input                       arst_n_i;
  input                       en_i;
  input [SPI_RATIO_GRADE-1:0] ratio_i;
  output                      spi_clk_o;

  /* ratio-driven clock generator */
  ratio_clk
    # (
        .RATIO_GRADE  (SPI_RATIO_GRADE)
      )
    ratio_clk_inst (
        .clk_i        (clk_i),
        .arst_n_i     (arst_n_i),
        .en_i         (en_i),
        .ratio_i      (ratio_i),
        .ratio_clk_o  (spi_clk_o)
      );

endmodule // spi_clk_gen
