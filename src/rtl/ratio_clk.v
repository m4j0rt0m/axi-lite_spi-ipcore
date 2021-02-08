/* -------------------------------------------------------------------------------
 * Project        : AXI-lite SPI IP Core
 * File           : ratio_clk.v
 * Description    : SPI ratio clock divider control
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
 *  3.0        | aruiz       | Sync'd a main fixed clock and a variable faster
 *             |             | clock for the axi write/read transactions
 * -----------------------------------------------------------------------------*/

module ratio_clk
# (
    parameter RATIO_GRADE = 3
  )
(/*AUTOARG*/
   // Outputs
   ratio_clk_o,
   // Inputs
   clk_i, arst_n_i, en_i, ratio_i
   );

  /* local parameters */
  localparam  RATIO_WIDTH = 2**RATIO_GRADE;

  /* local defines */
  `ifndef _L_SUB_SIZE_
  `define _L_SUB_SIZE_(x,y)  x-y
  `endif

  /* ports */
  input                   clk_i;
  input                   arst_n_i;
  input                   en_i;
  input [RATIO_GRADE-1:0] ratio_i;
  output reg              ratio_clk_o;

  wire  [RATIO_WIDTH-1:0] ratio_limit = ({{(`_L_SUB_SIZE_(RATIO_WIDTH,1)){1'b0}},1'b1} << ratio_i) - ({{(`_L_SUB_SIZE_(RATIO_WIDTH,1)){1'b0}},1'b1});
  reg   [RATIO_WIDTH-1:0] counter;

  always @ (posedge clk_i, negedge arst_n_i) begin
    if(~arst_n_i) begin
      counter     <=  {RATIO_WIDTH{1'b0}};
      ratio_clk_o <=  1'b0;
    end
    else begin
      if(~en_i) begin
        counter     <=  {RATIO_WIDTH{1'b0}};
        ratio_clk_o <=  1'b0;
      end
      else begin
        if(counter >= ratio_limit) begin
          counter     <=  {RATIO_WIDTH{1'b0}};
          ratio_clk_o <=  ~ratio_clk_o;
        end
        else
          counter     <=  counter + {{(`_L_SUB_SIZE_(RATIO_WIDTH,1)){1'b0}},1'b1};
      end
    end
  end

endmodule // ratio_clk
