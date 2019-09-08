/*
 * Author:        Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:          spi_ctrl.v
 * Description:   SPI Controller
 * Organizations: BSC; CIC-IPN
 */
module spi_ctrl
# (
    parameter SPI_RATIO_GRADE = 2,
    parameter BYTE            = 8
  )
(/*AUTOARG*/
   // Outputs
   spi_busy_o, spi_ready_o, spi_recv_data_o, spi_clk_o, spi_cs_n_o,
   spi_mosi_o,
   // Inputs
   clk_i, arst_n_i, spi_select_i, spi_msb_lsb_sel_i, spi_exchange_i,
   spi_ratio_i, spi_send_data_i, spi_miso_i
   );

  /* ctrl */
  input                         clk_i;
  input                         arst_n_i;
  input                         spi_select_i;
  input                         spi_msb_lsb_sel_i;
  input                         spi_exchange_i;
  output                        spi_busy_o;
  output                        spi_ready_o;
  input   [SPI_RATIO_GRADE-1:0] spi_ratio_i;

  /* data */
  input   [BYTE-1:0]            spi_send_data_i;
  output  [BYTE-1:0]            spi_recv_data_o;

  /* spi */
  output                        spi_clk_o;
  output                        spi_cs_n_o;
  output                        spi_mosi_o;
  input                         spi_miso_i;

  /* regs, wires and assigns */
  wire    spi_clk_en;
  assign  spi_cs_n_o = spi_select_i;

  /* spi clock generator */
  spi_clk_gen
    # (
        .SPI_RATIO_GRADE  (SPI_RATIO_GRADE)
      )
    spi_clk_gen_i0  (
      .clk_i      (clk_i),
      .arst_n_i   (arst_n_i),
      .en_i       (spi_clk_en),
      .ratio_i    (spi_ratio_i),
      .spi_clk_o  (spi_clk_o)
    );

  /* spi exchange byte module */
  spi_exch_byte
    # (
        .BYTE (BYTE)
      )
    spi_exch_byte_i0  (
      /* clks */
      .clk_i          (clk_i),
      .arst_n_i       (arst_n_i),
      .sclk_i         (spi_clk_o),

      /* ctrl */
      .msb_lsb_sel_i  (spi_msb_lsb_sel_i),
      .exchange_i     (spi_exchange_i),
      .sclk_en_o      (spi_clk_en),
      .busy_o         (spi_busy_o),
      .ready_o        (spi_ready_o),

      /* data */
      .data_i         (spi_send_data_i),
      .data_o         (spi_recv_data_o),

      /* mosi/miso */
      .miso_i         (spi_miso_i),
      .mosi_o         (spi_mosi_o)
    );


endmodule
