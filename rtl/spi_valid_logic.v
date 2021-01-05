/* -------------------------------------------------------------------------------
 * Project        : AXI-lite SPI IP Core
 * File           : spi_valid_logic.v
 * Description    : SPI Valid Data Logic
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

module spi_valid_logic
# (
    parameter DEPTH = 16
  )
(/*AUTOARG*/
   // Outputs
   valid_o, full_o, empty_o,
   // Inputs
   clk_i, arst_n_i, soft_rst_i, push_i, pull_i
   );

  input   clk_i;
  input   arst_n_i;
  input   soft_rst_i;

  input   push_i;
  input   pull_i;

  output  valid_o;
  output  full_o;
  output  empty_o;

  /* regs and wires */
  reg [DEPTH-1:0] valid_reg;

  /* assignments */
  assign  valid_o = valid_reg[0];
  assign  full_o  = valid_reg[DEPTH-1];
  assign  empty_o = ~valid_reg[0];

  /* valid logic */
  always @ (posedge clk_i, negedge arst_n_i)  begin
    if(~arst_n_i)
      valid_reg <=  {DEPTH{1'b0}};
    else  begin
      if(soft_rst_i)
        valid_reg <=  {DEPTH{1'b0}};
      else begin
        case({pull_i,push_i})
          2'b01:  begin  //..push
            valid_reg[0]            <=  1'b1;
            valid_reg[1+:(DEPTH-1)] <=  valid_reg[0+:(DEPTH-1)];  //..shift one bit to the left, set the lsb
          end
          2'b10:  begin  //..pull
            valid_reg[DEPTH-1]      <=  1'b0;
            valid_reg[0+:(DEPTH-1)] <=  valid_reg[1+:(DEPTH-1)];  //..shift one bit to the right, clear the msb
          end
          default:  valid_reg <=  valid_reg;
        endcase
      end
    end
  end

endmodule // spi_valid_logic
