/*
 * Author:        Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:          spi_clk_gen.v
 * Description:   SPI Clock Generator
 * Organizations: BSC; CIC-IPN
 */
module spi_clk_gen
# (
    parameter FREQ_CLK  = 100000000,  //..100MHz
    parameter FREQ_SPI  = 2000000     //..2MHz
  )
(/*AUTOARG*/
   // Outputs
   spi_clk_o,
   // Inputs
   clk_i, arst_n_i, en_i
   );

  /* flow control */
  input       clk_i;
  input       arst_n_i;
  input       en_i;

  /* spi clock */
  output  reg spi_clk_o;

  localparam  LIMIT = FREQ_CLK/(2*FREQ_SPI);

  reg [31:0]  counter;

  always @ (posedge clk_i, negedge arst_n_i)  begin
    if(~arst_n_i) begin
      counter   <=  0;
      spi_clk_o <=  0;
    end
    else  begin
      if(~en_i) begin
        counter   <=  0;
        spi_clk_o <=  0;
      end
      else  begin
        if(counter==LIMIT)  begin
          counter   <=  0;
          spi_clk_o <=  ~spi_clk_o;
        end
        else
          counter <=  counter + 1;
      end
    end
  end

endmodule
