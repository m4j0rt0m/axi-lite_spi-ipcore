/*
 * Author:        Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:          spi_clk_gen.v
 * Description:   SPI Clock Generator
 * Organizations: BSC; CIC-IPN
 */
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
